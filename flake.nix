{
  description = "Modular Nixlab Config";

  # Input Sources
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
      mkNixosSystem = hostname: nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs outputs; };
        modules = [
          # Main configuration file for this host
          ./hosts/${hostname}.nix
          # Add sops-nix module
          sops-nix.nixosModules.sops
        ];
      };
    in {
      # Package Definitions
      packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});

      # Code formatter configuration
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

      # Reusable Components
      overlays = import ./overlays { inherit inputs; };
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      # System Configurations
      nixosConfigurations = {
        nixace = mkNixosSystem "nixp5"; #nixace
        nixser = mkNixosSystem "nixk5"; #nixsun
        nixtop = mkNixosSystem "nixk4"; #nixtop
        nixbase = mkNixosSystem "nixk3"; #nixvat
        nixzer = mkNixosSystem "nixk1"; #nixzen
      };

      # Home Manager Configurations
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
