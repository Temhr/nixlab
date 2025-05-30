{ pkgs, ... }:

pkgs.mkShell {
  name = "nixlab-dev";

  buildInputs = with pkgs; [
    # NixOS tools
    nixos-rebuild
    home-manager

    # Secret management
    sops
    age
    ssh-to-age

    # Development tools
    git
    alejandra
    deadnix
    statix

    # Disk management
    parted
  ];

  shellHook = ''
    echo "🚀 NixLab Development Environment"
    echo "Available commands:"
    echo "  - nixos-rebuild: Rebuild NixOS configuration"
    echo "  - home-manager: Manage user environment"
    echo "  - sops: Edit encrypted secrets"
    echo "  - alejandra: Format Nix code"
    echo "  - deadnix: Find unused Nix code"
    echo "  - statix: Lint Nix code"
    echo ""
    echo "Available dev shells:"
    echo "  - default: Main development environment"
    echo "  - rust: Rust development"
    echo "  - python: Python development"
    echo "  - web: Web development"
    echo "  - security: Security tools"
    echo "  - minimal: Lightweight shell"
    echo ""
    echo "Usage: nix develop .#<shell-name>"
  '';
}
