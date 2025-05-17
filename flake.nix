{
  description = "Modular Nix Config with UUID-based system detection";

  #
  # Input Sources
  #
  inputs = {
    # NixOS package collections
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Environment management
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secret management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Application-specific flakes
    ghostty.url = "github:ghostty-org/ghostty";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, ghostty, zen-browser, ... } @ inputs:
    let
      inherit (self) outputs;
      lib = nixpkgs.lib;

      # Supported systems for cross-platform compatibility
      supportedSystems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      # Helper function to generate attributes for all supported systems
      forAllSystems = lib.genAttrs supportedSystems;

      # Import the UUID detection module
      uuidModule = import ./lib/modules/uuid-detection.nix;

      # System configurations - map UUIDs to config files
      # Replace these example UUIDs with your actual system UUIDs
      systems = {
        # Format: UUID = {configFile = "filename"; description = "Description";}
        "67e589ff-5de2-4784-a477-b88bd8822621" = {
          configFile = "nixk1";
          description = "Desktop";
        };
        "a34f7231-c938-4026-8ce5-3cb3ec51827c" = {
          configFile = "nixk3";
          description = "Server";
        };
        "a423347f-d8f3-11e3-9078-5634120000ff" = {
          configFile = "nixk4";
          description = "Laptop";
        };
        "87dfe389-1127-4e5b-a0d4-fed634b9f7fc" = {
          configFile = "nixk5";
          description = "Server 2";
        };
        "6a943fcd-8ae9-4909-8df2-8d4868ba8404" = {
          configFile = "nixp5";
          description = "Workstation";
        };
      };

      # Create a NixOS configuration for a specific system
      mkNixosSystem = uuid: { configFile, description ? "" }:
        lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs;
            systemUUID = uuid;
          };
          modules = [
            # UUID detection module
            uuidModule
            # System-specific configuration file
            ./hosts/${configFile}.nix
          ];
        };

    in {
      # Packages and utilities
      packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

      # Reusable components
      overlays = import ./overlays { inherit inputs; };
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      # System configurations by UUID
      nixosConfigurations =
        # Generate all UUID-specific configurations
        lib.mapAttrs mkNixosSystem systems //
        # Add a "current" configuration with auto-detection capability
        {
          # Special configuration that detects the current system's UUID
          current = lib.nixosSystem {
            specialArgs = { inherit inputs outputs systems; };
            modules = [
              # This is the auto-detection module that selects the right config
              ./lib/modules/auto-detect-system.nix
            ];
          };
        };

      # Home manager configurations
      # Currently disabled - uncomment when needed
      /*
      homeConfigurations = {
        "temhr" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager/home.nix
          ];
        };
      };
      */
    };
}
