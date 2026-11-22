{
  description = "Modular Nixlab Config";

  # ==========================================================================
  # INPUTS - External flake dependencies
  # ==========================================================================

  inputs = {
    # Core NixOS package collections (25.11 as default)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # flake-parts for dendritic pattern
    flake-parts.url = "github:hercules-ci/flake-parts";
    # import-tree recursively discovers every .nix file
    import-tree.url = "github:vic/import-tree";

    # Version Pinned Apps (2026-05-16).
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ol/ollama/package.nix
    nixpkgs-ollama.url = "github:nixos/nixpkgs/5fb42d154da0e77f3f00eb820f66fd012ff615a2";
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/op/open-webui/package.nix
    nixpkgs-open-webui.url = "github:nixos/nixpkgs/910564c14c038f431076737ea6a7c20e656bb980";
    # ComfyUI Pin is in nixlab/overlays/_comfyui-p5000.nix

    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.7.7.2";

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
    observability = {
      url = "github:Temhr/observability/v0.3.0-rc1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
      inputs.sops-nix.follows = "sops-nix";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  # ================================================================
  # OUTPUTS - thin root, all logic lives in flake/parts/
  # ================================================================
  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        #"aarch64-linux"
        #"i686-linux"
        "x86_64-linux"
        #"aarch64-darwin"
        #"x86_64-darwin"
      ];
      imports = [
        (inputs.import-tree ./flake)
        (inputs.import-tree ./hardware)
        (inputs.import-tree ./home)
        (inputs.import-tree ./hosts)
        (inputs.import-tree ./modules)
        (inputs.import-tree ./overlays)
        (inputs.import-tree ./shells)
        (inputs.import-tree ./sops)
        (inputs.import-tree ./stacks)
      ];
    };
}
