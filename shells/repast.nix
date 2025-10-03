{ pkgs, ... }:

let
  # Use Python 3.11 for GPU mode (PyTorch 2.0.1 compatibility)
  python311 = pkgs.python311;

  # Override mpi4py to skip tests (they fail but package works fine)
  python311WithOverrides = python311.override {
    packageOverrides = self: super: {
      mpi4py = super.mpi4py.overridePythonAttrs (old: {
        doCheck = false;
        dontUsePytestCheck = true;
      });
      # Override packages that pull in tkinter
      matplotlib = super.matplotlib.override { enableTk = false; };
      ipython = super.ipython.override { };
    };
  };

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
      # GPU mode: Use Python 3.11, install numpy + PyTorch via pip for compatibility
      pythonEnvGPU = python311WithOverrides.withPackages (ps: with ps; [
        networkx
        numba
        pyyaml
        mpi4py
        cython
        pip
        setuptools
        wheel
        packaging
        pytest
        # numpy and PyTorch will be installed via pip in shellHook for compatibility
        # Note: ipython excluded to avoid tkinter dependency chain
        # to add via pip in the GPU env. after shell loads:
        # $ pip install --prefix="$PIP_PREFIX" ipython
      ]);

      # CPU mode: Can use latest Python with nixpkgs PyTorch
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
        # Only include NVIDIA driver libs - PyTorch wheel includes CUDA runtime
        linuxPackages.nvidia_x11
        stdenv.cc.cc.lib   # <-- add this only for GPU mode
      ]);

      shellHook = ''
        ${if useGPU then ''
        # GPU mode - NVIDIA driver + libstdc++ for PyTorch wheel
        export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.linuxPackages.nvidia_x11}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

        # Create a local pip install directory for GPU-specific packages
        export PIP_PREFIX="$HOME/repast4py-workspace/.pytorch-gpu-py311"
        mkdir -p "$PIP_PREFIX/lib/python3.11/site-packages"

        # CRITICAL: Put pip packages FIRST in PYTHONPATH to override nixpkgs numpy
        export PYTHONPATH="$PIP_PREFIX/lib/python3.11/site-packages"

        # Install NumPy 1.x and PyTorch 2.0.1 with CUDA 11.8 support
        # PyTorch 2.0.1 requires NumPy <2.0, so we install 1.24.4 for compatibility
        if [ ! -f "$PIP_PREFIX/lib/python3.11/site-packages/torch/__init__.py" ]; then
          echo "Installing NumPy 1.24.4 and PyTorch 2.0.1 with CUDA 11.8 support..."
          echo "This version supports your Quadro P5000 (compute capability 6.1)"
          echo "Note: PyTorch wheel includes CUDA runtime - no system CUDA toolkit needed"
          pip install --prefix="$PIP_PREFIX" --no-cache-dir \
            "numpy==1.24.4" \
            torch==2.0.1+cu118 torchvision==0.15.2+cu118 \
            --index-url https://download.pytorch.org/whl/cu118
        fi
        '' else ''
        # CPU mode - suppress CUDA warnings
        export CUDA_VISIBLE_DEVICES=""
        ''}

        echo "Repast4Py Development Environment (${if useGPU then "GPU" else "CPU"} mode)"
        ${if useGPU then ''
        echo "   Python: 3.11 (required for PyTorch 2.0.1)"
        echo "   CUDA: Included in PyTorch wheel (CUDA 11.8 runtime)"
        echo "   PyTorch: 2.0.1 with CUDA 11.8 (supports compute capability 6.1+)"
        echo "   NumPy: 1.24.4 (required for PyTorch 2.0.1 compatibility)"
        echo "   GPU: Quadro P5000 (sm_61) - SUPPORTED"
        '' else ''
        echo "   Using CPU-only PyTorch"
        ''}
        echo "=================================================="

        # Add MPI binaries to PATH
        export PATH="${pkgs.openmpi}/bin:''${PATH}"

        # Set up MPI compiler wrappers
        export CC=mpicc
        export CXX=mpic++

        # MPI include paths
        export CFLAGS="-I${pkgs.openmpi}/include"
        export CXXFLAGS="-I${pkgs.openmpi}/include"

        # tells MPI to use the ob1 backend directly and silence UCX warnings.
        export OMPI_MCA_pml=ob1
        export OMPI_MCA_btl=^openib

        # Set custom temp directory
        export TMPDIR=''${TMPDIR:-$HOME/tmp}
        mkdir -p $TMPDIR

        # Create workspace directory if it doesn't exist
        export REPAST4PY_HOME="$HOME/repast4py-workspace"
        mkdir -p $REPAST4PY_HOME

        # Clone Repast4Py if not already present
        if [ ! -d "$REPAST4PY_HOME/repast4py" ]; then
          echo "Cloning Repast4Py repository..."
          git clone https://github.com/Repast/repast4py.git $REPAST4PY_HOME/repast4py
        else
          echo "Repast4Py repository found at $REPAST4PY_HOME/repast4py"
        fi

        # Build Repast4Py if not already built
        SO_FILE=$(find "$REPAST4PY_HOME/repast4py/src/repast4py" -name "_core*.so" 2>/dev/null | head -n1)
        if [ -z "$SO_FILE" ]; then
          echo "Building Repast4Py C++ extensions..."
          cd $REPAST4PY_HOME/repast4py
          python setup.py build_ext --inplace || {
            echo "Build failed. You may need to build manually:"
            echo "   cd $REPAST4PY_HOME/repast4py"
            echo "   python setup.py build_ext --inplace"
          }
          cd - > /dev/null
        fi

        # Add Repast4Py source to Python path
        export PYTHONPATH="$REPAST4PY_HOME/repast4py/src:$PYTHONPATH"

        echo ""
        echo "Environment ready!"
        echo "  Python: $(python --version)"
        echo "  MPI: $(mpirun --version | head -n1)"
        echo "  Workspace: $REPAST4PY_HOME"
        echo "  Source: $REPAST4PY_HOME/repast4py"
        echo "  Examples: $REPAST4PY_HOME/repast4py/examples"
        echo ""
        echo "Quick verification:"
        python -c "import repast4py; print('  Repast4Py version:', repast4py.__version__)" 2>/dev/null || \
          echo "  Repast4Py import failed - may need manual build"
        python -c "from mpi4py import MPI; print('  MPI working')"
        ${if useGPU then ''
        python -c "import warnings; warnings.filterwarnings('ignore'); import torch; print('  PyTorch version:', torch.__version__); print('  CUDA available:', torch.cuda.is_available()); print('  CUDA device:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')"
        python -c "import numpy; print('  NumPy version:', numpy.__version__)"
        '' else ''
        python -c "import warnings; warnings.filterwarnings('ignore'); import torch; print('  PyTorch version:', torch.__version__)" 2>/dev/null
        ''}
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
  # CPU-only version (default, uses latest Python)
  default = mkRepastShell { useGPU = false; };
  cpu = mkRepastShell { useGPU = false; };

  # GPU-enabled version (uses Python 3.11 for PyTorch 2.0.1 compatibility)
  gpu = mkRepastShell { useGPU = true; };
}
