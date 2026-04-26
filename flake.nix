{
  description = "Modular Nixlab Config";

  # ==========================================================================
  # INPUTS - External flake dependencies
  # ==========================================================================

  inputs = {
    # Core NixOS package collections (25.11 as default)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # flake-parts for dendritic pattern
    flake-parts.url = "github:hercules-ci/flake-parts";
    # import-tree recursively discovers every .nix file
    import-tree.url = "github:vic/import-tree";

    # Version Pinned Apps (2026-04-22).
    # nix flake metadata nixpkgs-unstable | grep "Revision"
    nixpkgs-ollama.url = "github:nixos/nixpkgs/0726a0ecb6d4e08f6adced58726b95db924cef57";
    # ComfyUI Pin is in nixlab/overlays/_comfyui-p5000.nix

    # User environment management
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Security & secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware support
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Application-specific flakes
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
        (inputs.import-tree ./flake)
        (inputs.import-tree ./hardware)
        (inputs.import-tree ./home)
        (inputs.import-tree ./hosts)
        (inputs.import-tree ./modules)
        (inputs.import-tree ./overlays)
        (inputs.import-tree ./shells)
      ];
    };
}
