{...}: {
  perSystem = {pkgs, ...}: {
    devShells.rust = pkgs.mkShell {
      name = "rust-dev";

      buildInputs = with pkgs; [
        # Rust toolchain
        rustc
        cargo
        rustfmt
        clippy
        rust-analyzer

        # Cargo extensions
        cargo-watch # auto-rebuild on file changes
        cargo-edit # cargo add / cargo rm
        cargo-audit # check dependencies for known vulnerabilities
        cargo-outdated # list outdated dependencies
        cargo-nextest # faster test runner

        # Build dependencies
        pkg-config
        openssl
        sqlite
      ];

      shellHook = ''
        echo "🦀 Rust Development Environment"
        echo "  Rust:  $(rustc --version)"
        echo "  Cargo: $(cargo --version)"
        echo ""
        echo "Cargo shortcuts:"
        echo "  cargo run / test / build --release / check / clippy"
        echo "  cargo watch -x run     auto-rebuild on changes"
        echo "  cargo nextest run      faster parallel test runner"
        echo "  cargo audit            check for vulnerability advisories"
      '';
    };
  };
}
