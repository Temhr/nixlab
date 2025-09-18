{ pkgs, ... }:

pkgs.mkShell {
    name = "repast";
    buildInputs = with pkgs; [
        python3
        python3Packages.pip
        python3Packages.virtualenv
        python3Packages.numpy
        python3Packages.mpi4py
        python3Packages.networkx
        python3Packages.matplotlib
        openmpi
        gcc
        pkg-config
    ];

    shellHook = ''
        export LD_LIBRARY_PATH=${pkgs.openmpi}/lib:$LD_LIBRARY_PATH
        export PYTHONPATH=""
        echo "Python development environment for Repast4Py ready"
    '';
};
