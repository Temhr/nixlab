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

      # UUID to hostname mapping
      uuidToHostname = {
        "00000000-0000-0000-0000-000000000001" = "nixk1"; # Example UUID for nixzer
        "00000000-0000-0000-0000-000000000002" = "nixk3"; # Example UUID for nixbase
        "a423347f-d8f3-11e3-9078-5634120000ff" = "nixk4"; # Example UUID for nixtop
        "00000000-0000-0000-0000-000000000004" = "nixk5"; # Example UUID for nixser
        "00000000-0000-0000-0000-000000000005" = "nixp5"; # Example UUID for nixace
      };

      # Function to get current system UUID and map to hostname
      getCurrentHostname = let
        # The path can vary between systems
        uuidPaths = [
          "/sys/class/dmi/id/product_uuid"
          "/sys/devices/virtual/dmi/id/product_uuid"
          "/etc/machine-id" # Fallback to machine-id if product_uuid is not available
        ];

        # Try to read from the first file that exists
        getFirstExistingFile = paths:
          if paths == [] then throw "No UUID file found"
          else let path = builtins.head paths;
            in if builtins.pathExists path
               then path
               else getFirstExistingFile (builtins.tail paths);

        # Get the UUID safely
        getUuid = let
          uuidPath = getFirstExistingFile uuidPaths;
        in builtins.readFile uuidPath;

        # Read the UUID and clean it
        uuid = lib.strings.removeSuffix "\n" (lib.strings.trim (getUuid));
      in
        if builtins.hasAttr uuid uuidToHostname
        then uuidToHostname.${uuid}
        else throw "Unknown system UUID: ${uuid}";

    in {
      # Package Definitions
      packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
      # Code formatter configuration
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
      # Reusable Components
      overlays = import ./overlays { inherit inputs; };
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;
      # System Configurations - indexed by UUID-mapped hostnames
      nixosConfigurations = {
        nixzer = mkNixosSystem "nixk1";
        nixbase = mkNixosSystem "nixk3";
        nixtop = mkNixosSystem "nixk4";
        nixser = mkNixosSystem "nixk5";
        nixace = mkNixosSystem "nixp5";
      };

      # Add a special attribute to directly access the current system's configuration
      # This allows you to use `nixos-rebuild switch --flake .#current`
      nixosConfigurations.current = self.nixosConfigurations.${getCurrentHostname} or (
        throw "Current system UUID not found in configuration"
      );

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
