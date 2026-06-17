{self, ...}: {
  flake.nixosModules.servc--syncthing-nixlab = {
    config,
    lib,
    pkgs,
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

        # NEW: Environment file for secrets (populated by nsops module)
        secretsEnvFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Path to environment file with Syncthing secrets.
            Automatically set by nsops--syncthing module.
            Contains: SYNCTHING_GUI_USER, SYNCTHING_GUI_PASSWORD_HASH, SYNCTHING_API_KEY
          '';
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
          assertion = cfg.enableGuiAuth -> (cfg.secretsEnvFile != null);
          message = ''
            Syncthing GUI authentication is enabled but no secretsEnvFile is provided.
            Either:
            1. Set enableGuiAuth = false; (no authentication)
            2. Import the nsops--syncthing module to provide secrets
          '';
        }
        {
          assertion = cfg.enableSSL -> (cfg.domain != null);
          message = "Syncthing enableSSL requires a domain to be set";
        }
      ];

      # ----------------------------------------------------------------------------
      # USER SETUP - Create Syncthing user and configure access
      # ----------------------------------------------------------------------------
      # Create syncthing system user if using default
      users.users.syncthing = lib.mkIf (cfg.user == "syncthing") {
        isSystemUser = true;
        group = cfg.group;
        home =
          if cfg.dataDir != null
          then cfg.dataDir
          else "/var/lib/syncthing";
        createHome = true;
        description = "Syncthing daemon user";
      };

      # Add main user to syncthing group for easy file access
      users.users.${config.nixlab.mainUser} = lib.mkIf (config.nixlab ? mainUser) {
        extraGroups = lib.mkAfter [cfg.group];
      };

      users.groups.syncthing = lib.mkIf (cfg.user == "syncthing" && cfg.group == "syncthing") {};

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
      # SECRETS PREPARATION SERVICE (only if GUI auth is enabled)
      # ----------------------------------------------------------------------------
      # A dedicated oneshot that writes /run/syncthing-credentials.env BEFORE
      # syncthing.service starts. This ensures the environment file exists at
      # unit-load time.
      systemd.services.syncthing-secrets = lib.mkIf (cfg.enableGuiAuth && cfg.secretsEnvFile != null) {
        description = "Write Syncthing credentials env file";
        wantedBy = ["syncthing.service"];
        before = ["syncthing.service"];
        after = ["sops-nix.service"];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "root";
        };

        script = ''
          # Read the decrypted secrets and create environment file
          GUI_USER=$(cat ${config.sops.secrets."syncthing/gui_user".path})
          GUI_PASS_HASH=$(cat ${config.sops.secrets."syncthing/gui_password_hash".path})
          API_KEY=$(cat ${config.sops.secrets."syncthing/api_key".path})

          cat > /run/syncthing-credentials.env << EOF
          SYNCTHING_GUI_USER=$GUI_USER
          SYNCTHING_GUI_PASSWORD_HASH=$GUI_PASS_HASH
          SYNCTHING_API_KEY=$API_KEY
          EOF

          chown ${cfg.user}:${cfg.group} /run/syncthing-credentials.env
          chmod 600 /run/syncthing-credentials.env
        '';
      };

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
        # Ensure secrets are ready before starting (only if GUI auth enabled)
        requires = lib.optionals (cfg.enableGuiAuth && cfg.secretsEnvFile != null) ["syncthing-secrets.service"];
        after = lib.optionals (cfg.enableGuiAuth && cfg.secretsEnvFile != null) ["syncthing-secrets.service"];

        serviceConfig =
          {
            # Restart on failure
            Restart = "on-failure";
            RestartSec = "10s";
          }
          // lib.optionalAttrs (cfg.enableGuiAuth && cfg.secretsEnvFile != null) {
            # Load environment file with secrets (only if auth enabled)
            EnvironmentFile = cfg.secretsEnvFile;
          };
      };

      # ----------------------------------------------------------------------------
      # NGINX REVERSE PROXY - Only configured if domain is set
      # ----------------------------------------------------------------------------
      services.nginx = lib.mkIf (cfg.domain != null) {
        enable = true;
        # Enable recommended security and performance settings
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        recommendedOptimisation = true;
        recommendedGzipSettings = true;

        virtualHosts.${cfg.domain} = {
          # Proxy all requests to Syncthing GUI
          locations."/" = {
            proxyPass = "http://${cfg.guiAddress}:${toString cfg.guiPort}";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
            '';
          };

          # Force HTTPS if SSL is enabled
          forceSSL = cfg.enableSSL;
          # Get automatic SSL certificate from Let's Encrypt
          enableACME = cfg.enableSSL;
        };
      };

      # ----------------------------------------------------------------------------
      # FIREWALL - Open necessary ports
      # ----------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
        # Open GUI port if not localhost-only
        lib.optionals (cfg.guiAddress != "127.0.0.1") [cfg.guiPort]
        # Also open HTTP/HTTPS if using reverse proxy
        ++ lib.optionals (cfg.domain != null) [80 443]
      );
    };
  };
}
