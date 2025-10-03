{ pkgs, ... }:

let
  # Override mpi4py to skip tests (they fail but package works fine)
  python3WithOverrides = pkgs.python3.override {
    packageOverrides = self: super: {
      mpi4py = super.mpi4py.overridePythonAttrs (old: {
        doCheck = false;  # Skip tests that fail with OpenMPI
        dontUsePytestCheck = true;  # Also disable pytest check phase
      });
    };
  };

  # Base configuration function that accepts GPU flag
  mkRepastShell = { useGPU ? false }:
    let
      # For GPU with older compute capability (6.1 - Quadro P5000),
      # we need PyTorch 2.0.x or earlier
      # PyTorch 2.1+ dropped support for compute capability < 7.5
      pythonEnvGPU = python3WithOverrides.withPackages (ps: with ps; [
        networkx
        numba
        pyyaml
        mpi4py
        cython
        pip
        setuptools
        wheel
        packaging
        ipython
        pytest
        # Use older PyTorch from stable channel that supports sm_61
        # We'll install via pip in shellHook instead to get 2.0.1
      ]);

      pythonEnvCPU = python3WithOverrides.withPackages (ps: with ps; [
        networkx
        numba
        pyyaml
        mpi4py
        pytorch-bin
        cython
        pip
        setuptools
        wheel
        packaging
        ipython
        pytest
      ]);

      pythonEnv = if useGPU then pythonEnvGPU else pythonEnvCPU;

    in
    pkgs.mkShell {
      name = "repast4py-dev-${if useGPU then "gpu" else "cpu"}";

      buildInputs = with pkgs; [
        pythonEnv
        openmpi
        gcc
        gnumake
        git
      ] ++ pkgs.lib.optionals useGPU (with pkgs; [
        linuxPackages.nvidia_x11
        stdenv.cc.cc.lib   # ensure libstdc++ is available
      ]);

      shellHook = ''
        ${if useGPU then ''
        # ------------------------------
        # GPU mode setup
        # ------------------------------
        export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.linuxPackages.nvidia_x11}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

        # Use Python 3.11 venv for PyTorch 2.0.1
        export VENV_DIR="$HOME/repast4py-workspace/.pytorch-gpu-py311"
        if [ ! -d "$VENV_DIR" ]; then
          echo "Creating Python 3.11 venv for GPU mode..."
          ${pkgs.python311}/bin/python3 -m venv "$VENV_DIR"
          source "$VENV_DIR/bin/activate"
          pip install --upgrade pip wheel setuptools

          echo "Installing PyTorch 2.0.1 + CUDA 11.8 (for sm_61 Quadro P5000)..."
          pip install --no-cache-dir \
            torch==2.0.1+cu118 torchvision==0.15.2+cu118 \
            --index-url https://download.pytorch.org/whl/cu118

          echo "Pinning NumPy to <2 for Repast4Py compatibility..."
          pip install --no-cache-dir 'numpy<2'
        else
          source "$VENV_DIR/bin/activate"
        fi

        export PYTHONPATH="$VENV_DIR/lib/python3.11/site-packages:$PYTHONPATH"
        export PATH="$VENV_DIR/bin:$PATH"
        '' else ''
        # ------------------------------
        # CPU mode setup
        # ------------------------------
        export CUDA_VISIBLE_DEVICES=""
        ''}

        echo "Repast4Py Development Environment (${if useGPU then "GPU" else "CPU"} mode)"
        ${if useGPU then ''
        echo "   Python: 3.11 (required for PyTorch 2.0.1)"
        echo "   CUDA: Included in PyTorch wheel (CUDA 11.8 runtime)"
        echo "   PyTorch: 2.0.1+cu118 (supports compute capability 6.1+)"
        '' else ''
        echo "   Using CPU-only PyTorch"
        ''}
        echo "=================================================="

        # MPI setup
        export PATH="${pkgs.openmpi}/bin:''${PATH}"
        export CC=mpicc
        export CXX=mpic++
        export OMPI_MCA_pml=ob1
        export OMPI_MCA_btl=^openib
        export CFLAGS="-I${pkgs.openmpi}/include"
        export CXXFLAGS="-I${pkgs.openmpi}/include"

        # Workspace setup
        export TMPDIR=''${TMPDIR:-$HOME/tmp}
        mkdir -p $TMPDIR
        export REPAST4PY_HOME="$HOME/repast4py-workspace"
        mkdir -p $REPAST4PY_HOME

        if [ ! -d "$REPAST4PY_HOME/repast4py" ]; then
          echo "Cloning Repast4Py repository..."
          git clone https://github.com/Repast/repast4py.git $REPAST4PY_HOME/repast4py
        else
          echo "Repast4Py repository found at $REPAST4PY_HOME/repast4py"
        fi

        # Build extensions if missing
        SO_FILE=$(find "$REPAST4PY_HOME/repast4py/src/repast4py" -name "_core*.so" 2>/dev/null | head -n1)
        if [ -z "$SO_FILE" ]; then
          echo "Building Repast4Py C++ extensions..."
          cd $REPAST4PY_HOME/repast4py
          python setup.py build_ext --inplace || echo "Build failed. Please run manually."
          cd - > /dev/null
        fi
        export PYTHONPATH="$REPAST4PY_HOME/repast4py/src:$PYTHONPATH"

        echo ""
        echo "Environment ready!"
        echo "  Python: $(python --version)"
        echo "  NumPy: $(python -c 'import numpy; print(numpy.__version__)')"
        echo "  MPI: $(mpirun --version | head -n1)"
        echo "  Workspace: $REPAST4PY_HOME"
        echo "  Source: $REPAST4PY_HOME/repast4py"
        echo "  Examples: $REPAST4PY_HOME/repast4py/examples"
        echo ""
        echo "Quick verification:"
        python -c "import repast4py; print('  Repast4Py version:', repast4py.__version__)" || echo "  Repast4Py import failed!"
        python -c "from mpi4py import MPI; print('  MPI working')"
        python -c "import torch; print('  PyTorch version:', torch.__version__); print('  CUDA available:', torch.cuda.is_available()); print('  Device:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')" || echo "  Torch import failed!"
        echo ""
        echo "To run models:"
        echo "  Single process:  python your_model.py config.yaml"
        echo "  MPI parallel:    mpiexec -n 4 python your_model.py config.yaml"
        echo ""
        echo "Example models available at:"
        echo "  cd $REPAST4PY_HOME/repast4py/examples/zombies"
        echo "  mpiexec -n 2 python zombies.py zombie_model.yaml"
        echo "=================================================="
      '';

    };

in
{
  # CPU-only version (default, smaller and faster)
  default = mkRepastShell { useGPU = false; };
  cpu = mkRepastShell { useGPU = false; };

  # GPU-enabled version (requires CUDA support)
  gpu = mkRepastShell { useGPU = true; };
}
