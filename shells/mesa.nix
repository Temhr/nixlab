{ pkgs, ... }:

let
  mkMesaShell = { useGPU ? false }:
    let
      # Both modes use empty pythonEnv - we'll create venvs for both
      pythonEnv = pkgs.buildEnv {
        name = "empty-python-env";
        paths = [ ];
      };

      nvidiaLibPath = if pkgs ? linuxPackages.nvidia_x11
                      then ":${pkgs.linuxPackages.nvidia_x11}/lib"
                      else "";
    in
    pkgs.mkShell {
      name = "mesa-dev-${if useGPU then "gpu" else "cpu"}";

      buildInputs = with pkgs; [
        pythonEnv
        gcc
        git
        zlib
        # For visualization backends
        cairo
        pkg-config
      ] ++ pkgs.lib.optionals useGPU (with pkgs; [
        linuxPackages.nvidia_x11
        stdenv.cc.cc.lib  # libstdc++.so.6 for PyTorch wheel
      ]);

      shellHook = ''
        # ============================================================
        # Library Setup
        # ============================================================

        # Ensure Nix-provided libs are visible to any Python interpreter/venv
        export LD_LIBRARY_PATH="${pkgs.zlib}/lib:${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.cairo}/lib${nvidiaLibPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

        # ============================================================
        # Mode-Specific Configuration
        # ============================================================

        ${if useGPU then ''
        # GPU Mode: Python 3.11 venv with CUDA support
        export VENV_DIR="$HOME/mesa-workspace/.mesa-gpu-py311"

        if [ ! -d "$VENV_DIR" ]; then
          echo "Creating Python 3.11 venv for GPU mode..."
          ${pkgs.python311}/bin/python3 -m venv "$VENV_DIR"
          source "$VENV_DIR/bin/activate"
          pip install --upgrade pip wheel setuptools

          echo "Installing Mesa and core dependencies..."
          pip install --no-cache-dir \
            mesa \
            numpy \
            pandas \
            networkx \
            matplotlib \
            seaborn \
            tqdm \
            scipy \
            jupyter \
            ipython \
            notebook \
            pytest \
            black \
            ruff

          echo "Installing PyTorch 2.0.1 + CUDA 11.8 for GPU-accelerated models..."
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
        # CPU Mode: Python 3.13 venv with Mesa and dependencies
        export VENV_DIR="$HOME/mesa-workspace/.mesa-cpu-py313"

        if [ ! -d "$VENV_DIR" ]; then
          echo "Creating Python 3.13 venv for CPU mode..."
          ${pkgs.python3}/bin/python3 -m venv "$VENV_DIR"
          source "$VENV_DIR/bin/activate"
          pip install --upgrade pip wheel setuptools

          echo "Installing Mesa and core dependencies..."
          pip install --no-cache-dir \
            mesa \
            numpy \
            pandas \
            networkx \
            matplotlib \
            seaborn \
            tqdm \
            scipy \
            jupyter \
            ipython \
            notebook \
            pytest \
            black \
            ruff
        else
          source "$VENV_DIR/bin/activate"
        fi

        # Ensure the venv's site-packages are first on PYTHONPATH and PATH
        export PYTHONPATH="$VENV_DIR/lib/python3.13/site-packages:$PYTHONPATH"
        export PATH="$VENV_DIR/bin:$PATH"

        export CUDA_VISIBLE_DEVICES=""
        ''}

        # ============================================================
        # Workspace Setup
        # ============================================================

        export TMPDIR=''${TMPDIR:-$HOME/tmp}
        mkdir -p $TMPDIR

        export MESA_HOME="$HOME/mesa-workspace"
        mkdir -p $MESA_HOME

        # Create directories for models and data
        mkdir -p $MESA_HOME/models
        mkdir -p $MESA_HOME/data
        mkdir -p $MESA_HOME/notebooks

        # ============================================================
        # Environment Information
        # ============================================================

        echo ""
        echo "============================================================"
        echo "Mesa Development Environment (${if useGPU then "GPU" else "CPU"} mode)"
        ${if useGPU then ''
        echo "  Python: 3.11 (PyTorch compatible)"
        echo "  CUDA: Provided by PyTorch wheel (11.8)"
        echo "  PyTorch: 2.0.1+cu118"
        '' else ''
        echo "  Python: 3.13 (CPU-only)"
        ''}
        echo "============================================================"
        echo ""
        echo "Environment ready!"
        echo "  Python: $(python --version)"

        # Check Mesa
        python - <<'PY' 2>/dev/null || echo "  Mesa import failed!"
import sys
try:
    import mesa
    print(f"  Mesa: {mesa.__version__}")
except Exception as e:
    print("  Mesa import error:", e, file=sys.stderr)
PY

        # Check core dependencies
        python - <<'PY' 2>/dev/null || echo "  Dependency check failed!"
import sys
try:
    import numpy as np
    import pandas as pd
    import networkx as nx
    import matplotlib
    print(f"  NumPy: {np.__version__}")
    print(f"  Pandas: {pd.__version__}")
    print(f"  NetworkX: {nx.__version__}")
    print(f"  Matplotlib: {matplotlib.__version__}")
except Exception as e:
    print("  Dependency import error:", e, file=sys.stderr)
PY

        # Check PyTorch (if GPU mode)
        ${if useGPU then ''
        python - <<'PY' 2>/dev/null || echo "  PyTorch check failed!"
import sys
try:
    import torch
    print("  PyTorch:", torch.__version__, "CUDA available:", torch.cuda.is_available())
except Exception as e:
    print("  PyTorch import error:", e, file=sys.stderr)
PY
        '' else ""}

        # ============================================================
        # Usage Instructions
        # ============================================================

        echo ""
        echo "Workspace structure:"
        echo "  Models:      $MESA_HOME/models/"
        echo "  Data:        $MESA_HOME/data/"
        echo "  Notebooks:   $MESA_HOME/notebooks/"
        echo ""
        echo "To run a model:"
        echo "  python your_model.py"
        echo ""
        echo "To start Jupyter:"
        echo "  jupyter notebook $MESA_HOME/notebooks"
        echo ""
        echo "Example: Create a simple model"
        echo "  cd $MESA_HOME/models"
        echo "  # See Mesa documentation: https://mesa.readthedocs.io/"
        echo "============================================================"
      '';
    };

in
{
  default = mkMesaShell { useGPU = false; };
  cpu     = mkMesaShell { useGPU = false; };
  gpu     = mkMesaShell { useGPU = true; };
}
