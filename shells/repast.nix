{ pkgs, ... }:

(pkgs.buildFHSUserEnv {
  name = "repast";
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
    glibc
    glibc.dev
    stdenv.cc.cc
    stdenv.cc.cc.lib
    zlib
    zlib.dev
    pkg-config
  ];

  multiPkgs = pkgs: with pkgs; [
    zlib
  ];

  runScript = "bash";

  profile = ''
    export CC=gcc
    export CXX=g++
    export CFLAGS="-I${pkgs.glibc.dev}/include"
    export CXXFLAGS="-I${pkgs.glibc.dev}/include"
    export LDFLAGS="-L${pkgs.glibc}/lib -L${pkgs.stdenv.cc.cc.lib}/lib"
    export LD_LIBRARY_PATH="${pkgs.glibc}/lib:${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH"
  '';
}).env
