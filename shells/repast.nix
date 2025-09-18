{ pkgs, ... }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python3
    python3Packages.pip
    python3Packages.virtualenv
    python3Packages.numpy
    python3Packages.mpi4py
    python3Packages.networkx
    openmpi
    gcc
    pkg-config
    stdenv.cc.cc.lib
    glibc
    zlib
  ];

  shellHook = ''
    export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.glibc}/lib:${pkgs.openmpi}/lib:${pkgs.zlib}/lib:$LD_LIBRARY_PATH"
    export CC=${pkgs.gcc}/bin/gcc
    export CXX=${pkgs.gcc}/bin/g++
    echo "Enhanced Repast4Py development environment ready"
  '';
}
