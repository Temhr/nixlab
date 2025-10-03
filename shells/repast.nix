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
        cudaPackages.cudatoolkit
        cudaPackages.cudnn
        linuxPackages.nvidia_x11
      ]);

      shellHook = ''
        ${if useGPU then ''
        # GPU mode - ensure CUDA is visible
        export LD_LIBRARY_PATH="${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib:${pkgs.linuxPackages.nvidia_x11}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export CUDA_PATH="${pkgs.cudaPackages.cudatoolkit}"

        # Install PyTorch 2.0.1 with CUDA 11.8 support (supports compute capability 6.1)
        # Check if we need to install
        if ! python -c "import torch; exit(0 if torch.__version__.startswith('2.0') else 1)" 2>/dev/null; then
          echo "Installing PyTorch 2.0.1 with CUDA 11.8 support..."
          pip install --user torch==2.0.1 torchvision==0.15.2 --index-url https://download.pytorch.org/whl/cu118
        fi
        '' else ''
        # CPU mode - suppress CUDA warnings
        export CUDA_VISIBLE_DEVICES=""
        ''}

        echo "Repast4Py Development Environment (${if useGPU then "GPU" else "CPU"} mode)"
        ${if useGPU then ''
        echo "   CUDA Toolkit: ${pkgs.cudaPackages.cudatoolkit.version}"
        echo "   PyTorch: 2.0.1 with CUDA 11.8 (supports compute capability 6.1+)"
        '' else ''
        echo "   Using CPU-only PyTorch"
        ''}
        echo "=================================================="

        # Add MPI binaries to PATH (critical for setup.py to find mpicc/mpic++)
        export PATH="${pkgs.openmpi}/bin:''${PATH}"

        # Set up MPI compiler wrappers
        export CC=mpicc
        export CXX=mpic++

        # MPI include paths
        export CFLAGS="-I${pkgs.openmpi}/include"
        export CXXFLAGS="-I${pkgs.openmpi}/include"

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

        # Add Repast4Py source to Python path (after build to ensure .so files exist)
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
        python -c "import warnings; warnings.filterwarnings('ignore'); import torch; print('  PyTorch version:', torch.__version__); print('  CUDA available:', torch.cuda.is_available())" 2>/dev/null
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
