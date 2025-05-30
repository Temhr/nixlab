{ pkgs, ... }:

pkgs.mkShell {
  name = "rust-dev";

  buildInputs = with pkgs; [
    # Rust toolchain
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer

    # Additional Rust tools
    cargo-watch
    cargo-edit
    cargo-audit
    cargo-outdated

    # Build tools
    pkg-config
    openssl

    # Common dependencies
    sqlite
  ];

  shellHook = ''
    echo "🦀 Rust Development Environment"
    echo "Rust version: $(rustc --version)"
    echo "Cargo version: $(cargo --version)"
    echo ""
    echo "Available tools:"
    echo "  - cargo: Rust package manager"
    echo "  - rustfmt: Code formatter"
    echo "  - clippy: Linter"
    echo "  - rust-analyzer: Language server"
    echo "  - cargo-watch: Auto-rebuild on changes"
    echo ""
    echo "Useful aliases:"
    alias cr="cargo run"
    alias ct="cargo test"
    alias cb="cargo build --release"
    alias cw="cargo watch -x run"
  '';
}
