{self, ...}: {
  flake.nixosModules.servc--syncthing-nixlab = {
    config,
    lib,
    pkgs,
    nixlabLib,
    ...
  }: let
    cfg = config.services.syncthing-nixlab;
  in {
    imports = [
      self.nixosModules.systm--ports-syncthing
    ];
    # ============================================================================
    # OPTIONS - Define what can be configured
    # ============================================================================
    options = {
      services.syncthing-nixlab = {
        # REQUIRED: Enable the service
        enable = lib.mkEnableOption "Syncthing service";

        # REQUIRED: User to run Syncthing as
        user = lib.mkOption {
          type = lib.types.str;
          default = "syncthing";
          example = "myuser";
          description = "User account under which Syncthing runs";
        };

        # OPTIONAL: Group for the Syncthing user
        group = lib.mkOption {
          type = lib.types.str;
          default = cfg.user;
          example = "users";
          description = "Group for Syncthing user";
        };

        # OPTIONAL: Enable GUI authentication
        enableGuiAuth = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable GUI authentication with username/password.
            When false, the GUI is accessible without credentials.
            Only enable authentication if exposing the GUI externally.
            Requires the nsops--syncthing module when enabled.
          '';
        };

        # OPTIONAL: Web GUI port
        guiPort = lib.mkOption {
          type = lib.types.port;
          default = 8384;
          description = "Port for Syncthing web GUI";
        };

        # OPTIONAL: IP to bind GUI to
        guiAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "IP address for web GUI (use 0.0.0.0 for all interfaces)";
        };

        # OPTIONAL: Domain for nginx reverse proxy
        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "sync.example.com";
          description = "Domain name for nginx reverse proxy (optional)";
        };

        # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt
        enableSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HTTPS with Let's Encrypt (requires domain)";
        };

        # OPTIONAL: Where to store Syncthing data
        dataDir = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = "/data/syncthing";
          description = "Directory for Syncthing data (null = auto)";
        };

        # OPTIONAL: Syncthing config directory
        configDir = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = "/home/user/.config/syncthing";
          description = "Config directory for Syncthing settings (overrides auto-detection)";
        };

        # OPTIONAL: Override devices configured in web GUI
        overrideDevices = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Override devices configured in web GUI with Nix config";
        };

        # OPTIONAL: Override folders configured in web GUI
        overrideFolders = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Override folders configured in web GUI with Nix config";
        };

        # OPTIONAL: Devices to sync with
        devices = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              id = lib.mkOption {
                type = lib.types.str;
                description = "Device ID (long string from 'Show ID' in GUI)";
              };
              addresses = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = ["dynamic"];
                description = "List of addresses (use 'dynamic' for auto-discovery)";
              };
              introducer = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Allow this device to introduce other devices";
              };
            };
          });
          default = {};
          example = lib.literalExpression ''
            {
              "my-laptop" = {
                id = "DEVICE-ID-GOES-HERE";
                addresses = [ "dynamic" ];
              };
            }
          '';
          description = "Devices to sync with (requires overrideDevices = true)";
        };

        # OPTIONAL: Directories to sync
        folders = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              path = lib.mkOption {
                type = lib.types.str;
                description = "Path to the folder on this device";
              };
              id = lib.mkOption {
                type = lib.types.str;
                description = "Folder ID (must match on all devices sharing this folder)";
              };
              label = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "Human-readable label";
              };
              devices = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "List of device names to share this folder with";
              };
              type = lib.mkOption {
                type = lib.types.enum ["sendreceive" "sendonly" "receiveonly"];
                default = "sendreceive";
                description = "Folder type: sendreceive, sendonly, or receiveonly";
              };
            };
          });
          default = {};
          example = lib.literalExpression ''
            {
              documents = {
                path = "/home/user/Documents";
                id = "documents-sync";
                label = "My Documents";
                devices = [ "my-laptop" "my-phone" ];
                type = "sendreceive";
              };
            }
          '';
          description = "Folders to sync (requires overrideFolders = true)";
        };

        # OPTIONAL: Auto-open firewall ports
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open firewall ports for Syncthing";
        };

        # OPTIONAL: Enable relay usage
        relaysEnabled = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable relay servers for NAT traversal";
        };

        # OPTIONAL: Enable local discovery
        localDiscovery = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable local network discovery";
        };

        # OPTIONAL: Enable global discovery
        globalDiscovery = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable global device discovery";
        };

        secretsEnvFile = lib.mkOption {
          type    = lib.types.nullOr lib.types.path;
          default = null;
          example = "/run/secrets/syncthing-env";
          description = ''
            Path to a KEY=value environment file injected into the Syncthing service.
            Required when enableGuiAuth = true.

            The file must contain:
              SYNCTHING_GUI_USER=your-username
              SYNCTHING_GUI_PASSWORD_HASH=your-bcrypt-hash
              SYNCTHING_API_KEY=your-api-key

            With sops-nix, create a secret whose content is the env file itself
            (format = "binary"), then set:
              secretsEnvFile = config.sops.secrets.syncthing-env.path;

            sops-nix decrypts the file before any service starts, so no oneshot
            preparation service is needed.
          '';
        };

        # OPTIONAL: allow opting out of the mainUser group membership
        # without coupling to a specific external option name
        extraUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["alice"];
          description = "Extra users to add to the groups";
        };
      };
    };

    # ============================================================================
    # CONFIG - What happens when the service is enabled
    # ============================================================================
    config = lib.mkIf cfg.enable {
      # ----------------------------------------------------------------------------
      # ASSERTIONS - Verify configuration is valid
      # ----------------------------------------------------------------------------
      assertions = [
      {
        assertion = !cfg.enableGuiAuth || cfg.secretsEnvFile != null;
        message = ''
          services.syncthing-nixlab: enableGuiAuth = true requires secretsEnvFile to be set.
          Provide a path to a KEY=value env file containing:
            SYNCTHING_GUI_USER=...
            SYNCTHING_GUI_PASSWORD_HASH=...
            SYNCTHING_API_KEY=...
          With sops-nix, declare a binary secret whose content IS the env file,
          then pass config.sops.secrets.<name>.path as secretsEnvFile.
        '';
      }
      (nixlabLib.mkSslAssertion {
        inherit (cfg) enableSSL domain;
        moduleName = "services.syncthing-nixlab";
      })
    ];

      # ----------------------------------------------------------------------------
      # USER SETUP - Create Syncthing user and configure access
      # ----------------------------------------------------------------------------
      # Create syncthing system user if using default
      users.users = lib.mkMerge (
        lib.optional (cfg.user == "syncthing")
          { syncthing = {
              isSystemUser = true;
              group        = cfg.group;
              home         = if cfg.dataDir != null
                            then cfg.dataDir
                            else "/var/lib/syncthing";
              createHome   = true;
              description  = "Syncthing daemon user";
            };
          }
        ++ lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
          (map (u: { ${u} = { extraGroups = [ cfg.group ]; }; })
            ([ config.nixlab.mainUser ] ++ cfg.extraUsers))
      );

      users.groups.syncthing =
        lib.mkIf (cfg.user == "syncthing" && cfg.group == "syncthing") {};

      # ----------------------------------------------------------------------------
      # DIRECTORY SETUP - Create necessary directories with proper permissions
      # ----------------------------------------------------------------------------
      systemd.tmpfiles.rules = let
        actualDataDir =
          if cfg.dataDir != null
          then cfg.dataDir
          else
            (
              if cfg.user == "syncthing"
              then "/var/lib/syncthing"
              else "/home/${cfg.user}/.config/syncthing"
            );
      in [
        "d ${actualDataDir} 0770 ${cfg.user} ${cfg.group} -"
      ];

      # ----------------------------------------------------------------------------
      # SYNCTHING SERVICE - Configure the built-in NixOS Syncthing module
      # ----------------------------------------------------------------------------
      services.syncthing = {
        enable = true;

        # User and group configuration
        user = cfg.user;
        group = cfg.group;

        # Data directory (main working directory)
        dataDir =
          if cfg.dataDir != null
          then cfg.dataDir
          else
            (
              if cfg.user == "syncthing"
              then "/var/lib/syncthing"
              else "/home/${cfg.user}/.config/syncthing"
            );

        # Config directory (where config.xml is stored)
        configDir = cfg.configDir;

        # Web GUI configuration
        guiAddress = "${cfg.guiAddress}:${toString cfg.guiPort}";

        # Open firewall ports for sync traffic
        openDefaultPorts = cfg.openFirewall;

        # Override GUI-configured devices and folders
        overrideDevices = cfg.overrideDevices;
        overrideFolders = cfg.overrideFolders;

        # Syncthing settings
        settings = {
          options = {
            # Enable/disable relay servers (help with NAT traversal)
            relaysEnabled = cfg.relaysEnabled;
            # Enable/disable local network discovery
            localAnnounceEnabled = cfg.localDiscovery;
            # Enable/disable global discovery servers
            globalAnnounceEnabled = cfg.globalDiscovery;
            # Enable NAT traversal
            natEnabled = true;
            # Start browser on GUI address change (disabled for servers)
            startBrowser = false;
          };

          # Configure GUI authentication only if enabled AND secrets are provided
          gui =
            if cfg.enableGuiAuth && cfg.secretsEnvFile != null
            then {
              user = "$SYNCTHING_GUI_USER";
              password = "$SYNCTHING_GUI_PASSWORD_HASH";
              apikey = "$SYNCTHING_API_KEY";
            }
            else {};

          # Configure devices if specified
          devices =
            lib.mapAttrs (_: device: {
              id = device.id;
              addresses = device.addresses;
              introducer = device.introducer;
            })
            cfg.devices;

          # Configure folders if specified
          folders =
            lib.mapAttrs (name: folder: {
              path = folder.path;
              id = folder.id;
              label =
                if folder.label != ""
                then folder.label
                else name;
              devices = folder.devices;
              type = folder.type;
            })
            cfg.folders;
        };
      };

      # ----------------------------------------------------------------------------
      # SERVICE CUSTOMIZATION - Additional systemd service configuration
      # ----------------------------------------------------------------------------
      systemd.services.syncthing = {
        serviceConfig = {
          Restart    = "on-failure";
          RestartSec = "10s";
        } // lib.optionalAttrs (cfg.secretsEnvFile != null) {
          EnvironmentFile = cfg.secretsEnvFile;
        };
      };

      # ----------------------------------------------------------------------------
      # NGINX REVERSE PROXY - Only configured if domain is set
      # ----------------------------------------------------------------------------
      services.nginx.enable = lib.mkIf (cfg.domain != null) true;

      services.nginx.virtualHosts = nixlabLib.mkNginxVirtualHost {
        inherit (cfg) domain enableSSL;
        listenAddress = cfg.guiAddress;
        port          = cfg.guiPort;
        extraConfig   = ''
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        '';
      };

      # ----------------------------------------------------------------------------
      # FIREWALL - Open necessary ports
      # ----------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall
        (nixlabLib.mkFirewallPorts {
          domain        = cfg.domain;
          listenAddress = cfg.guiAddress;
          servicePort   = cfg.guiPort;
        });
    };
  };
}
