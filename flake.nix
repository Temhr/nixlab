{
  description = "Modular Nixlab Config";

  # ==========================================================================
  # INPUTS - External flake dependencies
  # ==========================================================================

  inputs = {
    # Core NixOS package collections (stable 25.11 as default)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # flake-parts for dendritic pattern
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Version Pinned Apps (March 5-6th).
    # nix flake metadata nixpkgs-unstable | grep "Revision"
    nixpkgs-ollama.url = "github:nixos/nixpkgs/80bdc1e5ce51f56b19791b52b2901187931f5353";
    # ComfyUI Pin is in nixlab/overlays/comfyui-p5000.nix

    # User environment management
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # System management tools
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
    };

    # Security & secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware support
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Application-specific flakes
    ghostty = {
      url = "github:ghostty-org/ghostty";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    # Development tools
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ================================================================
  # OUTPUTS - thin root, all logic lives in flake/parts/
  # ================================================================
  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      imports = [
        ./flake/parts/overlays.nix
        ./flake/parts/packages.nix
        ./flake/parts/devshells.nix
        ./flake/parts/checks.nix
        ./flake/parts/nixos.nix
      ];
    };
}
