#!/usr/bin/env bash
#
# Repast4Py Installation Script for Debian-based Linux
# =====================================================
# This script automates the installation of Repast4Py, a distributed agent-based
# modeling framework that uses MPI for parallel processing.
#
# Usage:
#   ./install_repast4py.sh --cpu   # Install with CPU-only PyTorch (recommended)
#   ./install_repast4py.sh --gpu   # Install with GPU-enabled PyTorch
#
# What gets installed:
#   - System dependencies (MPI, compilers, Python tools)
#   - Python virtual environment at ~/repast4py-env
#   - Repast4Py source code at ~/repast4py
#   - Required Python packages (networkx, numba, PyTorch, etc.)
#

set -e  # Exit immediately if any command fails
        # This prevents partial installations if something goes wrong

# -------------------------------
# Step 1: Parse Command Line Arguments
# -------------------------------
# By default, we install the CPU-only version of PyTorch to save disk space
# and avoid unnecessary CUDA dependencies. Users can override with --gpu flag.

MODE="cpu"  # Default mode is CPU-only

# Loop through all command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --cpu) 
      MODE="cpu"   # Explicitly request CPU-only PyTorch
      ;;
    --gpu) 
      MODE="gpu"   # Request GPU-enabled PyTorch (requires CUDA)
      ;;
    *) 
      # Unknown argument - print error and exit
      echo "Unknown option: $1"
      echo "Usage: $0 [--cpu|--gpu]"
      exit 1
      ;;
  esac
  shift  # Move to next argument
done

echo "🔧 Installing Repast4Py in $MODE mode..."

# -------------------------------
# Step 2: Install System Dependencies
# -------------------------------
# Repast4Py requires several system-level packages:
#   - git: Version control, needed to clone the Repast4Py repository
#   - python3, python3-venv, python3-pip: Core Python tools
#   - build-essential: GCC compiler, make, and other build tools
#   - openmpi-bin: OpenMPI runtime executables (mpirun, mpiexec)
#   - libopenmpi-dev: OpenMPI development headers for compiling MPI code
#   - python3-mpi4py: Debian's packaged version of MPI4Py (Python MPI bindings)

echo "📦 Installing system dependencies..."
sudo apt-get update -y
sudo apt-get install -y \
  git \
  python3 python3-venv python3-pip \
  build-essential \
  openmpi-bin libopenmpi-dev \
  python3-mpi4py

# -------------------------------
# Step 3: Create Python Virtual Environment
# -------------------------------
# A virtual environment isolates Python packages from the system Python,
# preventing version conflicts and keeping the installation clean.
# We create it at ~/repast4py-env so it's easy to find and remove if needed.

echo "🐍 Setting up Python virtual environment..."

if [ ! -d "$HOME/repast4py-env" ]; then
  # Virtual environment doesn't exist yet - create it
  python3 -m venv ~/repast4py-env
  echo "Created new virtual environment at ~/repast4py-env"
else
  echo "Using existing virtual environment at ~/repast4py-env"
fi

# Activate the virtual environment
# All subsequent pip commands will install packages into this environment
source ~/repast4py-env/bin/activate

# Set custom temporary directory to avoid /tmp space issues
# Some systems have /tmp on a small partition or in RAM (tmpfs)
# Using ~/tmp ensures we have enough space for large downloads
export TMPDIR=$HOME/tmp
mkdir -p $TMPDIR
echo "Using $TMPDIR for temporary files"

# -------------------------------
# Step 4: Upgrade Core Python Build Tools
# -------------------------------
# We upgrade pip (package installer), setuptools (package builder), wheel
# (binary package format), and other tools to ensure smooth package installation.
# The --no-cache-dir flag prevents pip from caching downloads, saving disk space.

echo "⬆️ Upgrading pip and build tools..."
pip install --no-cache-dir --upgrade pip setuptools wheel build packaging

# -------------------------------
# Step 5: Install Cython from Source
# -------------------------------
# Cython is required to build Repast4Py's C++ extensions.
# On Python 3.13+, prebuilt wheels may not be available, so we force
# compilation from source using --no-binary :all:

echo "🔨 Installing Cython from source..."
pip install --no-cache-dir --no-binary :all: Cython

# -------------------------------
# Step 6: Clone or Update Repast4Py Source Code
# -------------------------------
# Repast4Py is installed from source rather than PyPI to ensure we get
# the latest version and can easily access example models.

echo "📥 Cloning/updating Repast4Py repository..."

if [ ! -d "$HOME/repast4py" ]; then
  # Repository doesn't exist - clone it fresh
  git clone https://github.com/Repast/repast4py.git ~/repast4py
  echo "Cloned Repast4Py to ~/repast4py"
else
  # Repository exists - update it to latest version
  cd ~/repast4py && git pull
  echo "Updated Repast4Py repository"
fi

# -------------------------------
# Step 7: Install Repast4Py in Editable Mode
# -------------------------------
# Installing with 'pip install -e' creates a link to the source directory
# instead of copying files. This allows us to:
#   1. Easily run example models from ~/repast4py/examples
#   2. Make changes to the source code without reinstalling
#   3. Update with git pull without reinstalling
#
# We need to set environment variables to tell the build system where
# to find MPI compilers and headers:
#   - CC/CXX: Use MPI compiler wrappers (mpicc/mpic++)
#   - CFLAGS/CXXFLAGS: Include paths for MPI headers

echo "🔧 Building and installing Repast4Py..."

# Set MPI compiler environment variables
# mpicc and mpic++ are wrapper scripts that automatically add MPI flags
export CC=mpicc
export CXX=mpic++

# Explicitly add MPI include directory for header files (mpi.h, etc.)
# This path is standard for Debian/Ubuntu OpenMPI installations
export CFLAGS="-I/usr/lib/x86_64-linux-gnu/openmpi/include"
export CXXFLAGS="-I/usr/lib/x86_64-linux-gnu/openmpi/include"

# Install in editable mode
pip install -e ~/repast4py

# -------------------------------
# Step 8: Install Required Python Libraries
# -------------------------------
# Repast4Py depends on several Python packages:
#   - networkx: Graph/network data structures (for agent relationship networks)
#   - numba: Just-in-time compiler for Python (accelerates numerical code)
#   - pyyaml: YAML parser (for reading configuration files)
#   - torch: PyTorch deep learning framework (used for some models)
#
# IMPORTANT: We install packages in two steps because:
#   1. networkx, numba, and pyyaml are on PyPI (standard Python package index)
#   2. torch has a special index for CPU-only builds
# Installing them together would try to fetch everything from the torch index,
# which doesn't have the other packages.

echo "📚 Installing Python dependencies..."

# Install standard packages from PyPI
pip install --no-cache-dir networkx numba pyyaml

# Install PyTorch based on selected mode
if [ "$MODE" = "cpu" ]; then
  # CPU-only version: smaller download, no CUDA dependencies
  # We use PyTorch's special index for CPU-optimized builds
  echo "Installing PyTorch (CPU version)..."
  pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu
else
  # Full version with GPU support (requires NVIDIA GPU and CUDA)
  echo "Installing PyTorch (GPU version)..."
  pip install --no-cache-dir torch
fi

# -------------------------------
# Step 9: Verify Installation
# -------------------------------
# Quick sanity checks to ensure all core components are working

echo ""
echo "✅ Verifying installation..."
echo "----------------------------"

# Re-activate environment to ensure all paths are set correctly
source ~/repast4py-env/bin/activate

# Test 1: Check Repast4Py imports and version
python -c "import repast4py; print('Repast4Py version:', repast4py.__version__)"

# Test 2: Check MPI4Py (MPI bindings for Python)
python -c "from mpi4py import MPI; print('MPI working')"

# Test 3: Check PyTorch version
python -c "import torch; print('PyTorch version:', torch.__version__)"

echo "----------------------------"

# -------------------------------
# Step 10: Run Example Model (Optional)
# -------------------------------
# Try to run the zombies example to verify everything works end-to-end.
# This test uses mpiexec to run with 2 processes in parallel.
#
# Note: This may fail or hang if:
#   - MPI networking is not configured properly
#   - Running as root without proper MPI settings
#   - Firewall blocks MPI communication
# These issues don't affect single-process runs or basic functionality.

echo ""
echo "🌀 Testing with example model..."

if [ -d ~/repast4py/examples/zombies ]; then
  cd ~/repast4py/examples/zombies
  
  if [ -f zombies.py ]; then
    # Run zombies example with 2 MPI processes
    # timeout: Kill after 30 seconds if it hangs
    # mpiexec: MPI launcher (equivalent to mpirun)
    # -n 2: Use 2 processes
    # || {...}: Execute fallback if command fails
    timeout 30 mpiexec -n 2 python zombies.py zombie_model.yaml || {
      echo "⚠️ Example test skipped or failed (MPI configuration may be needed)."
      echo "   This doesn't affect basic functionality - you can still use Repast4Py!"
    }
  else
    echo "⚠️ Zombies script not found, skipping example test."
  fi
else
  echo "⚠️ Examples directory not found, skipping example test."
fi

# -------------------------------
# Final Success Message
# -------------------------------
echo ""
echo "=========================================="
echo "✅ Repast4Py Installation Complete!"
echo "=========================================="
echo ""
echo "Installation details:"
echo "  Mode: $MODE"
echo "  Virtual environment: ~/repast4py-env"
echo "  Source code: ~/repast4py"
echo "  Examples: ~/repast4py/examples"
echo ""
echo "To use Repast4Py:"
echo "  1. Activate the environment:"
echo "     source ~/repast4py-env/bin/activate"
echo ""
echo "  2. Run your model:"
echo "     python your_model.py config.yaml"
echo ""
echo "  3. Run with MPI (parallel):"
echo "     mpiexec -n 4 python your_model.py config.yaml"
echo ""
echo "Available example models:"
echo "  - zombies: Zombie infection spread model"
echo "  - rndwalk: Random walker agents"
echo "  - rumor: Rumor spreading in a network"
echo "  - diffusion: Heat/substance diffusion"
echo ""
if [ "$MODE" = "cpu" ]; then
  echo "Note: Installed CPU-only PyTorch. For GPU support, reinstall with --gpu"
fi
echo ""
echo "For documentation, visit: https://repast.github.io/repast4py.site/"
echo "=========================================="
