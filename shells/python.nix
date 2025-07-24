{ pkgs, ... }:

pkgs.mkShell {
  name = "python-dev";

  buildInputs = with pkgs; [
    # Python
    python3
    python3Packages.pip
    python3Packages.virtualenv
    python3Packages.poetry

    # Development tools
    python3Packages.black
    python3Packages.flake8
    python3Packages.mypy
    python3Packages.pytest
    python3Packages.ipython
    python3Packages.jupyter

    # Common libraries
    python3Packages.requests
    python3Packages.numpy
    python3Packages.pandas

    mpich
  ];

  shellHook = ''
    echo "🐍 Python Development Environment"
    echo "Python version: $(python --version)"
    echo "Pip version: $(pip --version)"
    echo ""
    echo "Available tools:"
    echo "  - poetry: Dependency management"
    echo "  - black: Code formatter"
    echo "  - flake8: Linter"
    echo "  - mypy: Type checker"
    echo "  - pytest: Testing framework"
    echo "  - ipython/jupyter: Interactive development"
  '';
}
