{self, ...}: {
  flake.nixosModules.servc--glance-nixlab = {
    config,
    lib,
    pkgs,
    allHosts,
    ...
  }: let
    cfg = config.services.glance-nixlab;

    # Import the pages configuration from _glance-pages.nix
    pagesConfig = import ./_glance-pages.nix {inherit allHosts;};

    # Convert pages to a JSON file (will be converted to YAML in preStart)
    pagesJsonFile =
      builtins.toFile "glance-pages.json"
      (builtins.toJSON {pages = pagesConfig;});
  in {
    imports = [
      self.nixosModules.nsops--glance
    ];
    # ============================================================================
    # OPTIONS - Define what can be configured
    # ============================================================================
    options = {
      services.glance-nixlab = {
        # REQUIRED: Enable the service
        enable = lib.mkEnableOption "Glance dashboard service";

        # OPTIONAL: Port to listen on (default: 3004)
        port = lib.mkOption {
          type = lib.types.port;
          default = 3004;
          description = "Port for Glance to listen on";
        };

        # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
        };

        # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "dashboard.example.com";
          description = "Domain name for nginx reverse proxy (optional)";
        };

        # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
        # Only works if domain is set
        enableSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HTTPS with Let's Encrypt (requires domain)";
        };

        # OPTIONAL: Where to store Glance config (default: /var/lib/glance)
        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/glance";
          example = "/data/glance";
          description = "Directory for Glance configuration";
        };

        # OPTIONAL: Glance package to use (default: pkgs.glance)
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.glance;
          defaultText = lib.literalExpression "pkgs.glance";
          description = "The Glance package to use";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "glance";
          description = "User to run Glance as";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "glance";
          description = "Group to run Glance as";
        };

        # OPTIONAL: Auto-open firewall ports (default: true)
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open firewall ports";
        };
        # OPTIONAL: sops-nix path to a KEY=value env file for Glance API secrets.
        # Glance supports ${ENV_VAR} substitution in glance.yml.
        # Example env file content (KEY=value, one per line):
        #   GLANCE_GITHUB_TOKEN=ghp_your_token_here
        #   GLANCE_WEATHER_API_KEY=your_openweather_key
        # Reference in _glance-pages.nix as ${GLANCE_GITHUB_TOKEN} etc.
        secretsEnvFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = "/run/secrets/GLANCE_ENV";
          description = ''
            Path to a sops-decrypted KEY=value env file for Glance widget API keys.
            Variables are available in glance.yml as ''${VAR_NAME}.
            When null, no extra environment variables are injected.
          '';
        };
      };
    };

    # ============================================================================
    # CONFIG - What happens when the service is enabled
    # ============================================================================
    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.enableSSL -> cfg.domain != null;
          message = "services.glance-nixlab.enableSSL requires domain to be set";
        }
        {
          assertion = cfg.port >= 1024 && cfg.port <= 65535;
          message = "services.glance-nixlab.port must be between 1024-65535";
        }
        {
          assertion = cfg.secretsEnvFile == null || builtins.pathExists cfg.secretsEnvFile;
          message = "services.glance-nixlab.secretsEnvFile path does not exist";
        }
      ];

      # ----------------------------------------------------------------------------
      # DIRECTORY SETUP - Create necessary directories with proper permissions
      # ----------------------------------------------------------------------------
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0770 ${cfg.user} ${cfg.group} -"
      ];

      # ----------------------------------------------------------------------------
      # USER SETUP - Create dedicated system user for Glance
      # ----------------------------------------------------------------------------
      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        description = "Glance dashboard user";
      };

      users.groups.${cfg.group} = {};
      users.users.${config.nixlab.mainUser}.extraGroups = [cfg.group];

      # ----------------------------------------------------------------------------
      # GLANCE SERVICE - Configure the systemd service
      # ----------------------------------------------------------------------------
      systemd.services.glance = {
        description = "Glance Dashboard";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];

        serviceConfig =
          {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = cfg.dataDir;
            ExecStart = "${cfg.package}/bin/glance";
            Restart = "on-failure";
            RestartSec = "10s";
            TimeoutStartSec = "60s";
            TimeoutStopSec = "30s";

            # Security hardening
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [cfg.dataDir];
          }
          // lib.optionalAttrs (cfg.secretsEnvFile != null) {
            EnvironmentFile = cfg.secretsEnvFile;
          };

        # Always regenerate glance.yml so the pages section stays in sync
        # with _glance-pages.nix on every rebuild.
        #
        # Strategy:
        #   1. Write the server block (port + bind address) directly as YAML
        #   2. Convert _glance-pages.nix → JSON → YAML via remarshal
        #   3. Append the pages YAML to the server block
        preStart = ''
          set -euo pipefail

          # Validate directory permissions
          if [ ! -w ${cfg.dataDir} ]; then
            echo "ERROR: ${cfg.dataDir} is not writable by ${cfg.user}"
            exit 1
          fi

          # Write server configuration
          cat > ${cfg.dataDir}/glance.yml << 'SERVEREOF' || {
            echo "ERROR: Failed to write glance.yml"
            exit 1
          }
          server:
            port: ${toString cfg.port}
            host: "${cfg.listenAddress}"

          SERVEREOF

          # Convert pages JSON to YAML
          if ! ${pkgs.remarshal}/bin/remarshal \
            -i ${pagesJsonFile} \
            -o /tmp/glance-pages.yaml.tmp \
            -if json \
            -of yaml; then
              echo "ERROR: Failed to convert pages configuration"
              rm -f /tmp/glance-pages.yaml.tmp
              exit 1
          fi

          # Append pages configuration
          cat /tmp/glance-pages.yaml.tmp >> ${cfg.dataDir}/glance.yml || {
            echo "ERROR: Failed to append pages configuration"
            rm -f /tmp/glance-pages.yaml.tmp
            exit 1
          }

          rm -f /tmp/glance-pages.yaml.tmp

          # Set ownership and permissions
          chown ${cfg.user}:${cfg.group} ${cfg.dataDir}/glance.yml
          chmod 660 ${cfg.dataDir}/glance.yml

          echo "✓ Glance configuration generated successfully"
        '';
      };

      # ----------------------------------------------------------------------------
      # NGINX REVERSE PROXY - Only configured if domain is set
      # ----------------------------------------------------------------------------
      services.nginx.enable = lib.mkIf (cfg.domain != null) true;

      services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
        ${cfg.domain} = {
          forceSSL = cfg.enableSSL;
          enableACME = cfg.enableSSL;

          locations."/" = {
            proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
      };

      # ----------------------------------------------------------------------------
      # FIREWALL - Open necessary ports if requested
      # ----------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
        lib.optionals (cfg.domain == null) [cfg.port]
        ++ lib.optionals (cfg.domain != null) [80 443]
      );
    };
  };
}
