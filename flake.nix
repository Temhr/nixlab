{
  description = "Modular Nixlab Config";

  # Input Sources
  inputs = {
    # NixOS package collections - unstable as default, stable as overlay
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-24-11.url = "github:nixos/nixpkgs/nixos-24.11";

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

  outputs = { self, nixpkgs, nixpkgs-stable, nixpkgs-24-11, home-manager, disko, impermanence, sops-nix, nixos-hardware, ghostty, zen-browser, pre-commit-hooks, ... } @ inputs:
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

      # Host definitions with metadata
      hosts = {
        nixace = {
          system = "x86_64-linux";
          # Add host-specific modules here if needed
          # nixos-hardware.nixosModules.dell-xps-13-9310
          modules = [  ];
        };
        nixsun = {
          system = "x86_64-linux";
          modules = [  ];
        };
        nixtop = {
          system = "x86_64-linux";
          modules = [  ];
        };
        nixvat = {
          system = "x86_64-linux";
          modules = [  ];
        };
        nixzen = {
          system = "x86_64-linux";
          modules = [  ];
        };
        nixos = {
          system = "x86_64-linux";
          modules = [  ];
        };
      };

      # Common modules used by all hosts
      commonModules = [
        sops-nix.nixosModules.sops
        disko.nixosModules.disko
        # Add other common modules here
      ];

      # Enhanced helper function to create NixOS configurations
      mkNixosSystem = hostname: { system, modules ? [], ... }:
        let
          hostConfigPath = ./hosts/${hostname}.nix;
        in
        assert builtins.pathExists hostConfigPath;
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit disko impermanence inputs outputs hostname;
          };
          modules = commonModules ++ modules ++ [
            # Set hostname automatically
            { networking.hostName = hostname; }

            # Host-specific configuration
            hostConfigPath
          ];
        };

    in {
      # Package Definitions
      packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});

      # Code formatter configuration
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

      # Shell Enviroments - imported from separate files
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./shells { inherit pkgs; }
      );

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
            ${nixpkgs.lib.concatStringsSep "\n" (nixpkgs.lib.mapAttrsToList (name: config:
              "echo 'Building ${name}...' && nix build .#nixosConfigurations.${name}.config.system.build.toplevel --no-link"
            ) self.nixosConfigurations)}
          '';

          # Validate host definitions
          host-validation = pkgs.runCommand "validate-hosts" {} ''
            ${nixpkgs.lib.concatStringsSep "\n" (nixpkgs.lib.mapAttrsToList (hostname: config:
              "[ -f ${./hosts}/${hostname}.nix ] || (echo 'Missing host file: hosts/${hostname}.nix' && exit 1)"
            ) hosts)}
            echo "All host files exist" > $out
          '';
        });

      # Reusable Components
      overlays = import ./overlays { inherit inputs; };
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      # System Configurations - Now DRY!
      nixosConfigurations = nixpkgs.lib.mapAttrs mkNixosSystem hosts;
    };
}
