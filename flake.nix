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

  # ============================================================================
  # OUTPUTS
  # ============================================================================
  # Outputs are what your flake provides to the world.
  # The @ inputs syntax captures all inputs into a single variable.

  outputs = {
    disko,
    ghostty,
    home-manager,
    impermanence,
    nixpkgs,
    nixos-hardware,
    plasma-manager,
    pre-commit-hooks,
    self,
    sops-nix,
    zen-browser,
    ...
  } @ inputs:
    let
      # ========================================================================
      # CONFIGURATION CONSTANTS
      # ========================================================================
      # Centralize all configuration values to avoid "magic strings"
      # scattered throughout the code.

      # Reference to this flake's outputs (used for self-reference)
      inherit (self) outputs;

      # Import nixpkgs library functions for use throughout this file
      inherit (nixpkgs) lib;

      # Default system architecture for hosts (most common Linux setup)
      defaultSystem = "x86_64-linux";

      # List of all systems this flake should support
      # This enables cross-compilation and multi-platform support
      supportedSystems = [
        "aarch64-linux"   # 64-bit ARM Linux (Raspberry Pi, etc.)
        "i686-linux"      # 32-bit x86 Linux (legacy systems)
        "x86_64-linux"    # 64-bit x86 Linux (most desktops/servers)
        "aarch64-darwin"  # Apple Silicon macOS
        "x86_64-darwin"   # Intel macOS
      ];

      # ========================================================================
      # OVERLAYS
      # ========================================================================
      # Overlays modify or add packages to nixpkgs.

      allOverlays = [
        outputs.overlays.additions          # Custom packages you've defined
        outputs.overlays.modifications      # Modified versions of existing packages
        outputs.overlays.unstable-packages  # Access to unstable channel packages
        outputs.overlays.stable-packages    # Access to stable channel packages
      ];

      # ========================================================================
      # COMMON MODULES
      # ========================================================================
      # Modules that should be imported by ALL NixOS configurations.
      # These provide core functionality needed by every host.

      commonModules = [
        # Secret management module
        sops-nix.nixosModules.sops

        # Declarative disk management module
        disko.nixosModules.disko

        # Home-manager configuration (manages user environments)
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            # Use the same package set as NixOS (ensures consistency)
            useGlobalPkgs = true;

            # Install packages to /etc/profiles instead of user profiles
            # This is more efficient for system-wide installations
            useUserPackages = true;

            # Additional modules available to all home-manager configs
            sharedModules = [
              plasma-manager.homeModules.plasma-manager
            ];
          };
        }

        # Uncomment if you need to allow broken packages for CUDA, etc.
        # { nixpkgs.config.allowBroken = true; }
      ];

      # ========================================================================
      # HOST DEFINITIONS
      # ========================================================================
      # Each attribute defines a NixOS host (computer/server/VM).
      # Hosts inherit the defaultSystem unless specified otherwise.

      hosts = {
        nixace = { };
        nixsun = { };
        nixtop = { };
        nixvat = {
          # Host-specific modules only needed for this host
          modules = [
            "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
          ];
        };
        nixzen = { };
      };

      # ========================================================================
      # HELPER FUNCTIONS
      # ========================================================================

      # Creates an attribute set for each supported system
      # Example: forAllSystems (system: {...}) creates separate outputs
      # for x86_64-linux, aarch64-linux, etc.
      forAllSystems = lib.genAttrs supportedSystems;

      # Creates a complete NixOS system configuration
      # This is the main function that builds each host
      mkNixosSystem = hostname: {
        system ? defaultSystem,  # Use default if not specified
        modules ? [],            # Additional host-specific modules
        ...                      # Ignore any other attributes
      }:
        let
          # Path to the host's main configuration file
          hostConfigPath = ./hosts/${hostname}.nix;

          # Error message if host file doesn't exist
          errorMsg = ''
            Host configuration file not found: ${toString hostConfigPath}
            Please create hosts/${hostname}.nix
          '';
        in
        # Verify the host configuration file exists
        # If not, evaluation fails with our helpful error message
        assert builtins.pathExists hostConfigPath || throw errorMsg;

        # Build the actual NixOS system configuration
        lib.nixosSystem {
          # System architecture (x86_64-linux, etc.)
          inherit system;

          # Special arguments available to all modules in this configuration
          # These can be accessed in any module via function parameters
          specialArgs = {
            inherit inputs outputs hostname;
            # Removed: disko, impermanence (available via inputs: inputs.disko, inputs.impermanence)
            # flakePath provides the root directory of this flake
            flakePath = self;
          };

          # List of NixOS modules to evaluate
          # Order matters: later modules can override earlier ones
          modules =
            commonModules       # Shared by all hosts
            ++ modules          # Host-specific additional modules
            ++ [
              # Apply our overlays to make custom/modified packages available
              { nixpkgs.overlays = allOverlays; }
              # Set the hostname for this system
              { networking.hostName = hostname; }
              # Import the host's main configuration file
              hostConfigPath
            ];
        };

    in {
      # ========================================================================
      # FLAKE OUTPUTS
      # ========================================================================
      # These are the actual outputs that other flakes or commands can use.

      # ------------------------------------------------------------------------
      # OVERLAYS
      # Provide overlays for other flakes to use
      overlays = import ./overlays { inherit inputs; };

      # ------------------------------------------------------------------------
      # MODULES
      # Reusable NixOS and home-manager modules
      nixosModules = import ./modules/nixos;
      homeModules = import ./modules/home-manager;

      # ------------------------------------------------------------------------
      # PACKAGES
      # Custom packages defined in ./pkgs
      # Available for each supported system
      packages = forAllSystems (
        system: import ./pkgs nixpkgs.legacyPackages.${system}
      );

      # ------------------------------------------------------------------------
      # FORMATTER
      # Code formatter used by `nix fmt`
      # We use alejandra, a popular Nix formatter
      formatter = forAllSystems (
        system: nixpkgs.legacyPackages.${system}.alejandra
      );

      # ------------------------------------------------------------------------
      # DEVELOPMENT SHELLS
      # Development environments accessible via `nix develop`
      # Each shell is defined in ./shells
      devShells = forAllSystems (system:
        let
          # Create a nixpkgs instance with our overlays
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;  # Allow proprietary packages
            overlays = allOverlays;     # Apply our custom overlays
          };
        in
        # Import shell definitions from ./shells directory
        import ./shells { inherit pkgs; }
      );

      # ------------------------------------------------------------------------
      # CHECKS
      # Automated tests run by `nix flake check`
      # These verify code quality and build success
      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          # Pre-commit hooks for code quality
          # Runs formatting, linting, and other checks
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;  # Check all files in the flake
            hooks = {
              alejandra.enable = true;              # Nix formatting
              deadnix.enable = true;                # Find unused code
              statix.enable = true;                 # Nix linting
              check-merge-conflicts.enable = true;  # Detect merge conflicts
              trailing-whitespace.enable = true;    # Remove trailing spaces
            };
          };

          # Verify all NixOS configurations can build
          # This prevents accidentally breaking a configuration
          build-check = pkgs.writeShellScriptBin "build-check" ''
            echo "Checking if all NixOS configurations build..."
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: config:
                "echo 'Building ${name}...' && " +
                "nix build .#nixosConfigurations.${name}.config.system.build.toplevel --no-link"
              ) self.nixosConfigurations
            )}
          '';

          # Validate that all host configuration files exist
          host-validation = pkgs.runCommand "validate-hosts" {} ''
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (hostname: config:
                "[ -f ${./hosts}/${hostname}.nix ] || " +
                "(echo 'Missing host file: hosts/${hostname}.nix' && exit 1)"
              ) hosts
            )}
            echo "All host files exist" > $out
          '';
        }
      );

      # ------------------------------------------------------------------------
      # NIXOS CONFIGURATIONS
      # The actual NixOS system configurations
      # Each host from the `hosts` attribute set becomes a full configuration
      #
      # Usage:
      #   nixos-rebuild switch --flake .#nixsun
      #   nix build .#nixosConfigurations.nixace.config.system.build.toplevel
      nixosConfigurations = lib.mapAttrs mkNixosSystem hosts;
    };
}
