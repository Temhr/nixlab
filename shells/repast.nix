{ pkgs, ... }:

let
  # Choose between CPU and GPU PyTorch
  # Set useCPU = false for GPU support (requires CUDA-enabled system)
  useCPU = true;
  
  # Python environment with all required packages
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    # Core Repast4Py dependencies
    networkx
    numba
    pyyaml
    mpi4py
    
    # PyTorch - conditional CPU/GPU
    (if useCPU then pytorch-bin else pytorch)
    
    # Build tools
    cython
    pip
    setuptools
    wheel
    packaging
    
    # Development tools (optional but useful)
    ipython
    pytest
  ]);

  # Clone and build Repast4Py from source
  repast4py-src = pkgs.stdenv.mkDerivation {
    pname = "repast4py-source";
    version = "latest";
    
    src = pkgs.fetchFromGitHub {
      owner = "Repast";
      repo = "repast4py";
      rev = "master";  # or pin to specific commit/tag
      sha256 = pkgs.lib.fakeSha256;  # Replace with actual hash after first build
    };
    
    # Don't build yet, just make source available
    dontBuild = true;
    dontInstall = false;
    
    installPhase = ''
      mkdir -p $out
      cp -r . $out/
    '';
  };

in
pkgs.mkShell {
  name = "repast4py-dev";
  
  buildInputs = with pkgs; [
    # Python with all packages
    pythonEnv
    
    # MPI implementation
    openmpi
    
    # Build tools
    gcc
    gnumake
    git
  ];
  
  # Environment variables for MPI compilation
  shellHook = ''
    echo "🔧 Repast4Py Development Environment (${if useCPU then "CPU" else "GPU"} mode)"
    echo "=================================================="
    
    # Set up MPI compiler wrappers
    export CC=${pkgs.openmpi}/bin/mpicc
    export CXX=${pkgs.openmpi}/bin/mpic++
    
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
      echo "📥 Cloning Repast4Py repository..."
      git clone https://github.com/Repast/repast4py.git $REPAST4PY_HOME/repast4py
    else
      echo "✓ Repast4Py repository found at $REPAST4PY_HOME/repast4py"
    fi
    
    # Add Repast4Py to Python path for editable install
    export PYTHONPATH="$REPAST4PY_HOME/repast4py:$PYTHONPATH"
    
    # Build Repast4Py if not already built
    if [ ! -f "$REPAST4PY_HOME/repast4py/build/lib"*/repast4py/*.so ]; then
      echo "🔨 Building Repast4Py C++ extensions..."
      cd $REPAST4PY_HOME/repast4py
      python setup.py build_ext --inplace || {
        echo "⚠️  Build failed. You may need to build manually:"
        echo "   cd $REPAST4PY_HOME/repast4py"
        echo "   python setup.py build_ext --inplace"
      }
      cd - > /dev/null
    fi
    
    echo ""
    echo "Environment ready!"
    echo "  Python: $(python --version)"
    echo "  MPI: $(mpirun --version | head -n1)"
    echo "  Workspace: $REPAST4PY_HOME"
    echo "  Source: $REPAST4PY_HOME/repast4py"
    echo "  Examples: $REPAST4PY_HOME/repast4py/examples"
    echo ""
    echo "Quick verification:"
    python -c "import repast4py; print('  ✓ Repast4Py version:', repast4py.__version__)" 2>/dev/null || \
      echo "  ⚠️  Repast4Py import failed - may need manual build"
    python -c "from mpi4py import MPI; print('  ✓ MPI working')"
    python -c "import torch; print('  ✓ PyTorch version:', torch.__version__)"
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
  
  # Hint for users about GPU support
  passthru = {
    enableGPU = "Set useCPU = false in repast4py.nix for GPU support";
  };
}
