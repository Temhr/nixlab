{ pkgs, ... }:

(pkgs.buildFHSEnv {
  name = "repast4py-dev";
  targetPkgs = pkgs: with pkgs; [
    python3
    python3Packages.pip
    python3Packages.virtualenv
    python3Packages.numpy
    python3Packages.mpi4py
    python3Packages.setuptools
    python3Packages.wheel
    openmpi
    gcc
    binutils
    glibc
    glibc.dev
    glibc.static
    stdenv.cc.cc
    stdenv.cc.cc.lib
    zlib
    zlib.dev
    pkg-config
    libgcc
  ];

  multiPkgs = pkgs: with pkgs; [
    zlib
    glibc
  ];

  runScript = "bash";

  profile = ''
    export CC=gcc
    export CXX=g++
    # Use FHS-style paths that the linker expects
    export LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu:${pkgs.glibc}/lib:${pkgs.stdenv.cc.cc.lib}/lib"
    export C_INCLUDE_PATH="/usr/include:${pkgs.glibc.dev}/include"
    export CPLUS_INCLUDE_PATH="/usr/include:${pkgs.glibc.dev}/include"
    export LD_LIBRARY_PATH="${pkgs.glibc}/lib:${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH"
    echo "Repast4Py development environment ready!"
    echo "Create virtual environment: python -m venv repast-env"
    echo "Activate it: source repast-env/bin/activate"
    echo "Install repast4py: pip install repast4py"
  '';
}).env
