{...}: {
  perSystem = {pkgs, ...}: {
    devShells.python = pkgs.mkShell {
      name = "python-dev";

      buildInputs = with pkgs; [
        # Python runtime
        python3
        python3Packages.pip
        python3Packages.virtualenv

        # Dependency management — poetry itself, not just poetry-core
        poetry

        # Code quality
        python3Packages.black
        python3Packages.ruff # faster flake8 + isort replacement
        python3Packages.mypy
        python3Packages.pytest
        python3Packages.pytest-cov

        # Interactive development
        python3Packages.ipython
        python3Packages.jupyter

        # Common data libraries
        python3Packages.requests
        python3Packages.numpy
        python3Packages.pandas
      ];

      shellHook = ''
        echo "🐍 Python Development Environment"
        echo "  Python: $(python --version)"
        echo "  Pip:    $(pip --version)"
        echo "  Poetry: $(poetry --version)"
        echo ""
        echo "Tools:  black  ruff  mypy  pytest  ipython  jupyter"
        echo ""
        echo "Tip: use 'python -m venv .venv && source .venv/bin/activate'"
        echo "     for project-isolated dependencies."
      '';
    };
  };
}
