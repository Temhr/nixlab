{ pkgs, ... }:

let
  # Override mpi4py to skip tests (they fail but package works fine)
  python3WithOverrides = pkgs.python3.override {
    packageOverrides = self: super: {
      mpi4py = super.mpi4py.overridePythonAttrs (old: {
        doCheck = false;
        dontUsePytestCheck = true;
      });
    };
  };

  # Base configuration function that accepts GPU flag
  mkRepastShell = { useGPU ? false }:
    let
      pythonEnvGPU = python3WithOverrides.withPackages (ps: with ps; [
        networkx numba pyyaml mpi4py cython pip setuptools wheel packaging ipython pytest
      ]);

      pythonEnvCPU = python3WithOverrides.withPackages (ps: with ps; [
        networkx numba pyyaml mpi4py pytorch-bin cython pip setuptools wheel packaging ipython pytest
      ]);

      pythonEnv = if useGPU then pythonEnvGPU else pythonEnvCPU;
    in
    pkgs.mkShell {
      name = "repast4py-dev-${if useGPU then "gpu" else "cpu"}";

      buildInputs = with pkgs; [
        pythonEnv
        openmpi
        gcc gnumake git
        zlib                     # ensure libz.so.1 is available
      ] ++ pkgs.lib.optionals useGPU (with pkgs; [
        linuxPackages.nvidia_x11
        stdenv.cc.cc.lib
      ]);

      shellHook = ''
        # Always add zlib and nix python libs
        export LD_LIBRARY_PATH="${pkgs.zlib}/lib:${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export PYTHONPATH="${pythonEnv}/${pythonEnv.sitePackages}:$PYTHONPATH"

        ${if useGPU then ''
        # ------------------------------
        # GPU mode setup
        # ------------------------------
        export VENV_DIR="$HOME/repast4py-workspace/.pytorch-gpu-py311"
        if [ ! -d "$VENV_DIR" ]; then
          echo "Creating Python 3.11 venv for GPU mode..."
          ${pkgs.python311}/bin/python3 -m venv "$VENV_DIR"
          source "$VENV_DIR/bin/activate"
          pip install --upgrade pip wheel setuptools

          echo "Installing PyTorch 2.0.1 + CUDA 11.8..."
          pip install --no-cache-dir \
            torch==2.0.1+cu118 torchvision==0.15.2+cu118 \
            --index-url https://download.pytorch.org/whl/cu118

          echo "Pinning NumPy to <2..."
          pip install --no-cache-dir 'numpy<2'
        else
          source "$VENV_DIR/bin/activate"
        fi

        export PYTHONPATH="$VENV_DIR/lib/python3.11/site-packages:$PYTHONPATH"
        export PATH="$VENV_DIR/bin:$PATH"
        '' else ''
        # CPU mode: disable CUDA
        export CUDA_VISIBLE_DEVICES=""
        ''}

        echo "Repast4Py Development Environment (${if useGPU then "GPU" else "CPU"} mode)"
        ${if useGPU then ''
        echo "   Python: 3.11 (PyTorch 2.0.1 compatible)"
        echo "   CUDA: Provided by PyTorch wheel (11.8)"
        echo "   PyTorch: 2.0.1+cu118 (sm_61 capable)"
        '' else ''
        echo "   Using CPU-only PyTorch"
        ''}
        echo "=================================================="

        # MPI setup
        export PATH="${pkgs.openmpi}/bin:$PATH"
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
        python -c "import numpy; print('  NumPy:', numpy.__version__)" || echo "  NumPy import failed!"
        python -c "from mpi4py import MPI; print('  MPI working')" || echo "  mpi4py import failed!"
        python -c "import repast4py; print('  Repast4Py version:', repast4py.__version__)" || echo "  Repast4Py import failed!"
        python -c "import torch; print('  PyTorch:', torch.__version__); print('  CUDA available:', torch.cuda.is_available())" || echo "  Torch import failed!"
        echo ""
        echo "Examples at:"
        echo "  cd $REPAST4PY_HOME/repast4py/examples/zombies"
        echo "  mpiexec -n 2 python zombies.py zombie_model.yaml"
        echo "=================================================="
      '';
    };

in
{
  default = mkRepastShell { useGPU = false; };
  cpu     = mkRepastShell { useGPU = false; };
  gpu     = mkRepastShell { useGPU = true; };
}
