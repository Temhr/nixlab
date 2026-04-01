{...}: {
  perSystem = {pkgs, ...}: let
    python3WithOverrides = pkgs.stable.python3.override {
      packageOverrides = _: super: {
        mpi4py = super.mpi4py.overridePythonAttrs (_: {
          doCheck = false;
          dontUsePytestCheck = true;
        });
      };
    };

    mkRepastShell = {useGPU ? false}: let
      # GPU mode: use python311 directly from pkgs so `python3` is available
      # before the venv is activated (needed for `python3 -m venv` and the
      # status checks at the bottom of shellHook).
      pythonEnvGPU = pkgs.python311;

      pythonEnvCPU = python3WithOverrides.withPackages (ps:
        with ps; [
          networkx
          numba
          pyyaml
          mpi4py
          torch-bin
          cython
          pip
          setuptools
          wheel
          packaging
          ipython
          pytest
        ]);

      pythonEnv =
        if useGPU
        then pythonEnvGPU
        else pythonEnvCPU;

      nvidiaLibPath =
        if pkgs ? linuxPackages.nvidia_x11
        then ":${pkgs.linuxPackages.nvidia_x11}/lib"
        else "";
    in
      pkgs.mkShell {
        name = "repast4py-dev-${
          if useGPU
          then "gpu"
          else "cpu"
        }";

        buildInputs = with pkgs.stable;
          [
            pythonEnv
            openmpi
            gcc
            gnumake
            git
            zlib
          ]
          ++ pkgs.lib.optionals useGPU (with pkgs; [
            linuxPackages.nvidia_x11
            stdenv.cc.cc.lib
          ]);

        shellHook = ''
          # ============================================================
          # Library and Compiler Setup
          # ============================================================

          export LD_LIBRARY_PATH="${pkgs.zlib}/lib:${pkgs.openmpi}/lib:${pkgs.stdenv.cc.cc.lib}/lib${nvidiaLibPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

          export PATH="${pkgs.openmpi}/bin:$PATH"
          export MPICC="${pkgs.openmpi}/bin/mpicc"

          export CC=mpicc
          export CXX=mpic++
          export OMPI_MCA_pml=ob1
          export OMPI_MCA_btl=^openib
          export CFLAGS="-I${pkgs.openmpi}/include"
          export CXXFLAGS="-I${pkgs.openmpi}/include"

          # ============================================================
          # Mode-Specific Configuration
          # ============================================================

          ${
            if useGPU
            then ''
              export VENV_DIR="$HOME/shelf/projects/repast4py-workspace/.pytorch-gpu-py311"

              if [ ! -d "$VENV_DIR" ]; then
                echo "Creating clean Python 3.11 venv for GPU mode..."
                # python311 is now in buildInputs so `python3` exists here
                python3 -m venv "$VENV_DIR"
                source "$VENV_DIR/bin/activate"
                pip install --upgrade pip wheel setuptools

                echo "Installing runtime Python deps into venv..."
                MPICC="$MPICC" pip install --no-cache-dir \
                  'numpy<2' cython mpi4py numba pyyaml \
                  networkx packaging ipython pytest

                echo "Installing PyTorch 2.0.1 + CUDA 11.8 (sm_61 support)..."
                pip install --no-cache-dir \
                  torch==2.0.1+cu118 torchvision==0.15.2+cu118 \
                  --index-url https://download.pytorch.org/whl/cu118
              else
                source "$VENV_DIR/bin/activate"
              fi

              # Make venv python the default for this session AND subshells
              export PATH="$VENV_DIR/bin:$PATH"
              export PYTHONPATH="$VENV_DIR/lib/python3.11/site-packages:$PYTHONPATH"
              export LD_LIBRARY_PATH="${pkgs.linuxPackages.nvidia_x11}/lib:$LD_LIBRARY_PATH"

              # Canonical `python` alias so scripts using bare `python` work
              export PYTHON="$VENV_DIR/bin/python"
            ''
            else ''
              export CUDA_VISIBLE_DEVICES=""
              # Point PYTHON at the Nix-managed interpreter
              export PYTHON="$(which python3)"
            ''
          }

          # ============================================================
          # Workspace Setup
          # ============================================================

          export TMPDIR=''${TMPDIR:-$HOME/tmp}
          mkdir -p $TMPDIR

          export REPAST4PY_HOME="$HOME/shelf/projects/repast4py-workspace"
          mkdir -p $REPAST4PY_HOME

          if [ ! -d "$REPAST4PY_HOME/repast4py" ]; then
            echo "Cloning Repast4Py repository..."
            git clone https://github.com/Repast/repast4py.git $REPAST4PY_HOME/repast4py
          else
            echo "Repast4Py repository found at $REPAST4PY_HOME/repast4py"
          fi

          SO_FILE=$(find "$REPAST4PY_HOME/repast4py/src/repast4py" -name "_core*.so" 2>/dev/null | head -n1)
          if [ -z "$SO_FILE" ]; then
            echo "Building Repast4Py C++ extensions..."
            cd $REPAST4PY_HOME/repast4py
            # Use $PYTHON so both GPU (venv) and CPU (Nix) paths work
            $PYTHON setup.py build_ext --inplace || \
              echo "Build failed. Please run: cd $REPAST4PY_HOME/repast4py && python3 setup.py build_ext --inplace"
            cd - > /dev/null
          fi

          export PYTHONPATH="$REPAST4PY_HOME/repast4py/src:$PYTHONPATH"

          # ============================================================
          # Environment Information
          # ============================================================

          echo ""
          echo "============================================================"
          echo "Repast4Py Development Environment (${
            if useGPU
            then "GPU"
            else "CPU"
          } mode)"
          ${
            if useGPU
            then ''
              echo "  Python: 3.11 (PyTorch 2.0.1 compatible)"
              echo "  CUDA: Provided by PyTorch wheel (11.8)"
              echo "  PyTorch: 2.0.1+cu118"
            ''
            else ''
              echo "  Using CPU-only PyTorch"
            ''
          }
          echo "============================================================"
          echo ""
          echo "Environment ready!"
          # Use $PYTHON (set above) so the correct interpreter is always found
          echo "  Python: $($PYTHON --version)"

          $PYTHON - <<'PY' 2>/dev/null || echo "  NumPy import failed!"
          import sys
          try:
              import numpy as np
              print(f"  NumPy: {np.__version__}")
          except Exception as e:
              print("  NumPy import error:", e, file=sys.stderr)
          PY

          $PYTHON - <<'PY' 2>/dev/null || echo "  mpi4py import failed!"
          import sys
          try:
              from mpi4py import MPI
              print("  MPI working")
          except Exception as e:
              print("  mpi4py import error:", e, file=sys.stderr)
          PY

          $PYTHON - <<'PY' 2>/dev/null || echo "  Repast4Py / PyTorch import failed!"
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
              print("  PyTorch import error:", e, file=sys.stderr)
          PY

          echo ""
          echo "To run models:"
          echo "  Single process:  python3 your_model.py config.yaml"
          echo "  MPI parallel:    mpiexec -n 4 python3 your_model.py config.yaml"
          echo ""
          echo "Example models available at:"
          echo "  cd $REPAST4PY_HOME/repast4py/examples/zombies"
          echo "  mpiexec -n 2 python3 zombies.py zombie_model.yaml"
          echo "============================================================"
        '';
      };
  in {
    devShells.repast = mkRepastShell {useGPU = false;};
    devShells.repast-cpu = mkRepastShell {useGPU = false;};
    devShells.repast-gpu = mkRepastShell {useGPU = true;};
  };
}
