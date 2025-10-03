{ pkgs, ... }:

let
  # Override mpi4py tests for CPU (we won't use nix-python mpi4py in GPU mode)
  python3WithOverrides = pkgs.python3.override {
    packageOverrides = self: super: {
      mpi4py = super.mpi4py.overridePythonAttrs (old: {
        doCheck = false;
        dontUsePytestCheck = true;
      });
    };
  };

  mkRepastShell = { useGPU ? false }:
    let
      # GPU: empty pythonEnv so nixpkgs python site-packages do not interfere
      pythonEnvGPU = pkgs.buildEnv {
        name = "empty-python-env";
        paths = [ ];
      };

      # CPU: keep using nixpkgs python for reproducible CPU-only dev
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
        gcc
        gnumake
        git
        zlib             # provide libz.so.1 for NumPy / wheels
      ] ++ pkgs.lib.optionals useGPU (with pkgs; [
        linuxPackages.nvidia_x11
        stdenv.cc.cc.lib  # libstdc++.so.6 for PyTorch wheel
      ]);

      shellHook = ''
        # Ensure Nix-provided libs are visible to any Python interpreter/venv
        export LD_LIBRARY_PATH="${pkgs.zlib}/lib:${pkgs.openmpi}/lib:${pkgs.stdenv.cc.cc.lib}/lib${pkgs.linuxPackages.nvidia_x11:+:}${pkgs.linuxPackages.nvidia_x11}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

        # Ensure we use Nix's mpicc/mpiexec when building/using mpi4py
        export PATH="${pkgs.openmpi}/bin:$PATH"
        export MPICC="${pkgs.openmpi}/bin/mpicc"

        ${if useGPU then ''
        # ------------------------------
        # GPU mode (isolated Python 3.11 venv)
        # ------------------------------
        export VENV_DIR="$HOME/repast4py-workspace/.pytorch-gpu-py311"

        if [ ! -d "$VENV_DIR" ]; then
          echo "Creating clean Python 3.11 venv for GPU mode..."
          ${pkgs.python311}/bin/python3 -m venv "$VENV_DIR"
          source "$VENV_DIR/bin/activate"
          pip install --upgrade pip wheel setuptools

          echo "Installing runtime Python deps into venv (numpy<2, mpi4py, etc.)..."
          # Use MPICC from Nix so mpi4py builds correctly and links to Nix OpenMPI libs
          MPICC="$MPICC" pip install --no-cache-dir \
            'numpy<2' \
            cython \
            mpi4py \
            numba \
            pyyaml \
            networkx \
            packaging \
            ipython \
            pytest

          echo "Installing PyTorch 2.0.1 + CUDA 11.8 (sm_61 support)..."
          pip install --no-cache-dir \
            torch==2.0.1+cu118 torchvision==0.15.2+cu118 \
            --index-url https://download.pytorch.org/whl/cu118
        else
          source "$VENV_DIR/bin/activate"
        fi

        # Ensure the venv's site-packages are first on PYTHONPATH and PATH
        export PYTHONPATH="$VENV_DIR/lib/python3.11/site-packages:$PYTHONPATH"
        export PATH="$VENV_DIR/bin:$PATH"

        # GPU-specific LD paths (NVIDIA driver libs)
        export LD_LIBRARY_PATH="${pkgs.linuxPackages.nvidia_x11}/lib:$LD_LIBRARY_PATH"

        '' else ''
        # ------------------------------
        # CPU mode -- keep using nix python
        # ------------------------------
        export CUDA_VISIBLE_DEVICES=""
        ''}

        echo "Repast4Py Development Environment (${if useGPU then "GPU" else "CPU"} mode)"
        ${if useGPU then ''
        echo "   Python: 3.11 (PyTorch 2.0.1 compatible)"
        echo "   CUDA: Provided by PyTorch wheel (11.8)"
        echo "   PyTorch: 2.0.1+cu118"
        '' else ''
        echo "   Using CPU-only PyTorch"
        ''}
        echo "=================================================="

        # MPI compiler wrappers and flags (helpful for building ext modules)
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

        # Build C++ extensions if missing (uses current active python -> venv in GPU)
        SO_FILE=$(find "$REPAST4PY_HOME/repast4py/src/repast4py" -name "_core*.so" 2>/dev/null | head -n1)
        if [ -z "$SO_FILE" ]; then
          echo "Building Repast4Py C++ extensions..."
          cd $REPAST4PY_HOME/repast4py
          python setup.py build_ext --inplace || echo "Build failed. Please run: cd $REPAST4PY_HOME/repast4py && python setup.py build_ext --inplace"
          cd - > /dev/null
        fi

        # Add repast4py source to PYTHONPATH
        export PYTHONPATH="$REPAST4PY_HOME/repast4py/src:$PYTHONPATH"

        echo ""
        echo "Environment ready!"
        echo "  Python: $(python --version)"
        # NumPy may fail to import if LD paths are missing; show informative checks
        python - <<'PY' 2>/dev/null || echo "  NumPy import failed!"
import sys
try:
    import numpy as np
    print(f"  NumPy: {np.__version__}")
except Exception as e:
    print("  NumPy import error:", e, file=sys.stderr)
PY

        # Check mpi4py (this requires that mpi libs are exportable into LD_LIBRARY_PATH)
        python - <<'PY' 2>/dev/null || echo "  mpi4py import failed!"
import sys
try:
    from mpi4py import MPI
    print("  MPI working")
except Exception as e:
    print("  mpi4py import error:", e, file=sys.stderr)
PY

        # Repast4Py and torch checks
        python - <<'PY' 2>/dev/null || echo "  Repast4Py / torch import failed!"
import sys
try:
    import repast4py
    print("  Repast4Py version:", repast4py.__version__)
except Exception as e:
    print("  Repast4Py import error:", e, file=sys.stderr)
try:
    import torch
    print("  PyTorch:", torch.__version__, "CUDA available:", torch.cuda.is_available())
except Exception as e:
    print("  Torch import error:", e, file=sys.stderr)
PY

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
  default = mkRepastShell { useGPU = false; };
  cpu     = mkRepastShell { useGPU = false; };
  gpu     = mkRepastShell { useGPU = true; };
}
