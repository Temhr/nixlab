# Data analysis and database tooling shell.
# Useful alongside the homelab services (Grafana, Prometheus, Loki).
{...}: {
  perSystem = {pkgs, ...}: {
    devShells.data = pkgs.mkShell {
      name = "data-dev";

      buildInputs = with pkgs; [
        # Query tools
        sqlite
        duckdb # fast in-process analytical SQL
        pgcli # postgres CLI with autocomplete
        mycli # mysql/mariadb CLI with autocomplete

        # Data wrangling
        miller # awk/sed/cut for CSV, TSV, JSON, and more
        csvkit # suite of tools for CSV files
        jq
        yq-go

        # Visualisation helpers
        gnuplot # scriptable plotting

        # Python data stack
        python3
        python3Packages.pandas
        python3Packages.numpy
        python3Packages.matplotlib
        python3Packages.ipython
        python3Packages.jupyterlab
      ];

      shellHook = ''
        echo "📊 Data Development Environment"
        echo ""
        echo "Databases:   sqlite  duckdb  pgcli  mycli"
        echo "Wrangling:   miller  csvkit  jq  yq"
        echo "Python:      pandas  numpy  matplotlib  jupyterlab"
        echo ""
        echo "Start JupyterLab:  jupyter lab"
        echo "Query a CSV:       mlr --csv stats1 -a mean -f price data.csv"
      '';
    };
  };
}
