{ pkgs, ... }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python3
    python3Packages.pip
    python3Packages.virtualenv
    python3Packages.numpy
    python3Packages.mpi4py
    python3Packages.setuptools
    python3Packages.wheel
    openmpi
    gcc
    glibc.dev
    stdenv.cc.cc
    stdenv.cc.cc.lib
    pkg-config
    zlib.dev
  ];

  shellHook = ''
    export CC=${pkgs.gcc}/bin/gcc
    export CXX=${pkgs.gcc}/bin/g++
    export CFLAGS="-I${pkgs.glibc.dev}/include"
    export CXXFLAGS="-I${pkgs.glibc.dev}/include"
    export LDFLAGS="-L${pkgs.glibc}/lib -L${pkgs.stdenv.cc.cc.lib}/lib"
    export LD_LIBRARY_PATH="${pkgs.glibc}/lib:${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.openmpi}/lib:$LD_LIBRARY_PATH"
    export PKG_CONFIG_PATH="${pkgs.openmpi}/lib/pkgconfig:$PKG_CONFIG_PATH"
    echo "Development environment with C/C++ headers ready"
  '';
}
