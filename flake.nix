{
  description = "Modular Nixlab Config";

  # Input Sources
  inputs = {
    # NixOS package collections - unstable as default, stable as overlay
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";

    # Environment management
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = { url = "github:nix-community/impermanence"; };

    # Secret management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware detection and configuration
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Application-specific flakes
    ghostty.url = "github:ghostty-org/ghostty";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    # Pre-commit hooks for code quality (optional)
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, disko, impermanence, sops-nix, nixos-hardware, ghostty, zen-browser, pre-commit-hooks, ... } @ inputs:
    let
      inherit (self) outputs;

      # Supported systems for cross-platform compatibility
      supportedSystems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      # Helper function to generate attributes for all supported systems
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;


      # Helper function to create NixOS configurations with common parameters
      mkNixosSystem = hostname: system: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit disko impermanence inputs outputs; };
        modules = [

          # Add sops-nix module
          sops-nix.nixosModules.sops

          # Import Disko module
          disko.nixosModules.disko

          # Main configuration file for this host
          ./hosts/${hostname}.nix
        ];
      };
    in {
      # Package Definitions
      packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});

      # Code formatter configuration
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

      # Development shells
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
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
              alejandra  # Nix formatter
              deadnix    # Find dead Nix code
              statix     # Nix linter

              # Disk management
              parted

              # Optional: if you use VS Code
              # nixd  # Nix language server
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
              echo "Example usage:"
              echo "  sudo nixos-rebuild switch --flake .#nixace"
              echo "  home-manager switch --flake .#user@nixace"
            '';
          };
        });

      # Flake checks for code quality and build verification
      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          # Pre-commit hooks check
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              # Nix formatting
              alejandra.enable = true;
              # Find dead code
              deadnix.enable = true;
              # Nix linting
              statix.enable = true;
              # Check for merge conflicts
              check-merge-conflicts.enable = true;
              # Check for trailing whitespace
              trailing-whitespace.enable = true;
            };
          };

          # Build check - ensures all configurations can build
          build-check = pkgs.writeShellScriptBin "build-check" ''
            echo "Checking if all NixOS configurations build..."
            ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (name: config:
              "echo 'Building ${name}...' && nix build .#nixosConfigurations.${name}.config.system.build.toplevel --no-link"
            ) self.nixosConfigurations)}
          '';
        });

      # Reusable Components
      overlays = import ./overlays { inherit inputs; };
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      # System Configurations
      nixosConfigurations = {
        nixace = mkNixosSystem "nixace" "x86_64-linux";
        nixsun = mkNixosSystem "nixsun" "x86_64-linux";
        nixtop = mkNixosSystem "nixtop" "x86_64-linux";
        nixvat = mkNixosSystem "nixvat" "x86_64-linux";
        nixzen = mkNixosSystem "nixzen" "x86_64-linux";
        nixos = mkNixosSystem "nixos" "x86_64-linux";
      };
    };
}
