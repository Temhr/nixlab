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

      # UUID to configuration mapping
      systemConfigs = {
        # Format: UUID = "config-file-name";
        "67e589ff-5de2-4784-a477-b88bd8822621" = "nixk1"; # Desktop
        "a34f7231-c938-4026-8ce5-3cb3ec51827c" = "nixk3"; # Server
        "a423347f-d8f3-11e3-9078-5634120000ff" = "nixk4"; # Laptop
        "87dfe389-1127-4e5b-a0d4-fed634b9f7fc" = "nixk5"; # Server 2
        "6a943fcd-8ae9-4909-8df2-8d4868ba8404" = "nixp5"; # Workstation
        # Add more UUIDs and their corresponding config files as needed
        # Note: Replace these example UUIDs with your actual system UUIDs
      };

      # Helper function to create NixOS configurations with common parameters
      mkNixosSystem = uuid: configFile: nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;
          systemUUID = uuid;  # Pass the UUID to the configuration
        };
        modules = [
          # Common module for all systems that provides UUID-based identification
          ({ config, lib, ... }: {
            # Import system-specific configuration based on UUID
            imports = [ ./hosts/${configFile}.nix ];

            # Set system.build.installBootLoader to detect the UUID at runtime
            system.build.installBootLoader = lib.mkForce (
              ''
                #!/bin/sh
                currentUUID=$(cat /sys/class/dmi/id/product_uuid 2>/dev/null ||
                              dmidecode -s system-uuid 2>/dev/null ||
                              echo "unknown")
                echo "Detected System UUID: $currentUUID"

                # Continue with the regular boot loader installation
                ${config.system.build.installBootLoader.orig}
              ''
            );
          })
        ];
      };
    in {
      #
      # Package Definitions
      #
      packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});

      # Code formatter configuration
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

      #
      # Reusable Components
      #
      overlays = import ./overlays { inherit inputs; };
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      # Add a common module that can be used for UUID-based configuration
      lib = {
        # Helper function to get the current system UUID
        getSystemUUID = pkgs: ''
          ${pkgs.util-linux}/bin/cat /sys/class/dmi/id/product_uuid 2>/dev/null || \
          ${pkgs.dmidecode}/bin/dmidecode -s system-uuid 2>/dev/null || \
          echo "unknown"
        '';
      };

      #
      # System Configurations
      #
      nixosConfigurations =
        # Generate configurations for each UUID in systemConfigs
        nixpkgs.lib.mapAttrs (uuid: configFile:
          mkNixosSystem uuid configFile
        ) systemConfigs // {
          # Add a special "current" configuration that detects the UUID at runtime
          current = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs outputs; };
            modules = [
              # Module that dynamically detects the system UUID and imports the right config
              ({ config, pkgs, lib, ... }: {
                # This script detects the UUID and includes the appropriate configuration
                imports = [
                  # Add a boot-time script to print the UUID for debugging
                  ({ ... }: {
                    boot.postBootCommands = ''
                      systemUUID=$(cat /sys/class/dmi/id/product_uuid 2>/dev/null ||
                                  dmidecode -s system-uuid 2>/dev/null ||
                                  echo "unknown")
                      echo "Running on system with UUID: $systemUUID" > /var/log/system-uuid.log
                    '';
                  })

                  # Import the dynamically determined configuration
                  "/run/current-system/configuration.nix"
                ];

                # Use the environment to store the script to detect the UUID
                system.activationScripts.detectUUID = {
                  text = ''
                    # Detect the current system's UUID
                    currentUUID=$(cat /sys/class/dmi/id/product_uuid 2>/dev/null ||
                                  dmidecode -s system-uuid 2>/dev/null ||
                                  echo "unknown")
                    echo "Detected System UUID: $currentUUID"

                    # Get the configuration file for this UUID
                    configFile="${toString ./hosts}/"
                    case "$currentUUID" in
                      ${lib.concatStringsSep "\n      " (
                        lib.mapAttrsToList (uuid: configFile:
                          ''${uuid}) configFile="${configFile}.nix" ;;''
                        ) systemConfigs
                      )}
                      *)
                        echo "Warning: Unknown system UUID: $currentUUID" >&2
                        echo "Using default configuration."
                        configFile="${toString ./hosts}/default.nix"
                        ;;
                    esac

                    # Create a symlink to the right configuration
                    mkdir -p /run/current-system
                    echo "Using configuration file: $configFile"
                    ln -sf "$configFile" /run/current-system/configuration.nix
                  '';
                  deps = [];
                };
              })
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
