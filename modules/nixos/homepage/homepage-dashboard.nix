{ config, lib, pkgs, ... }:

let
  cfg = config.services.homepage-custom;

  # Import the services configuration from services.nix
  servicesConfig = import ./services.nix;
  # Convert services to JSON file (will be converted to YAML in preStart)
  servicesJsonFile = builtins.toFile "services.json"
    (builtins.toJSON servicesConfig);
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.homepage-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Homepage service";

      # OPTIONAL: Port to listen on (default: 3000)
      port = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = "Port for Homepage to listen on";
      };

      # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
      # Use "0.0.0.0" for access from other devices
      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
      };

      # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "home.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      # Only works if domain is set
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      # OPTIONAL: Where to store Homepage config (default: /var/lib/homepage)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/homepage";
        example = "/data/homepage";
        description = "Directory for Homepage configuration and data";
      };

      # OPTIONAL: Homepage package to use (default: pkgs.homepage-dashboard)
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.homepage-dashboard;
        defaultText = lib.literalExpression "pkgs.homepage-dashboard";
        description = "The Homepage package to use";
      };

      # OPTIONAL: Allowed hostnames/IPs for host validation (default: ["*"] = all)
      # Homepage validates the Host header for security
      allowedHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "*" ];
        example = [ "localhost" "127.0.0.1" "home.example.com" "192.168.1.100" ];
        description = "List of allowed hostnames/IPs (use [\"*\"] to allow all)";
      };

      # OPTIONAL: Auto-open firewall ports (default: true)
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports for HTTP/HTTPS";
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # ----------------------------------------------------------------------------
    # USER SETUP - Create dedicated system user for Homepage
    # ----------------------------------------------------------------------------
    users.users.homepage = {
      isSystemUser = true;
      group = "homepage";
      home = cfg.dataDir;
      extraGroups = [ "users" ];
    };

    users.groups.homepage = {};

    users.users.temhr.extraGroups = [ "homepage" ];

    # ----------------------------------------------------------------------------
    # DIRECTORY SETUP - Create necessary directories with proper permissions
    # ----------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
    "d ${cfg.dataDir} 0770 homepage homepage -"
    ];

    # ----------------------------------------------------------------------------
    # HOMEPAGE SERVICE - Configure the systemd service
    # ----------------------------------------------------------------------------
    systemd.services.homepage = {
      description = "Homepage Dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "local-fs.target" ];

      # Environment variables for Homepage configuration
      environment = {
        HOMEPAGE_CONFIG_DIR = "${cfg.dataDir}/config";
        PORT = toString cfg.port;
        HOSTNAME = cfg.bindIP;
        # Host validation: comma-separated list (no spaces)
        HOMEPAGE_ALLOWED_HOSTS = lib.concatStringsSep "," cfg.allowedHosts;
      };

      # Fix config file permissions on startup
      # Note: preStart inherits User/Group from serviceConfig
      preStart = let
        # Use /tmp for temporary file since preStart runs as homepage user
        servicesYamlTmp = "/tmp/homepage-services.yaml.tmp";
      in ''

        mkdir ${cfg.dataDir}/config/
        chown  ${cfg.dataDir}/config/ homepage:homepage
        chmod 0770 ${cfg.dataDir}/config/

        # Convert service rules from services.nix: JSON → YAML
        ${pkgs.remarshal}/bin/remarshal \
          -i ${servicesJsonFile} \
          -o ${servicesYamlTmp} \
          -if json \
          -of yaml

        # Copy temp file to final location
        cp -f ${servicesYamlTmp} ${cfg.dataDir}/config/services.yaml
        chmod 664 ${cfg.dataDir}/config/services.yaml

        # Clean up temp file
        rm -f ${servicesYamlTmp}
      '';

      serviceConfig = {
        Type = "simple";
        User = "homepage";
        Group = "homepage";
        # NOTE: WorkingDirectory removed - Homepage uses HOMEPAGE_CONFIG_DIR env var
        ExecStart = "${cfg.package}/bin/homepage";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening - relaxed when using /home directory
        NoNewPrivileges = true;
        PrivateTmp = true;
        # Temporarily disable ProtectSystem to test
        ProtectSystem = if lib.hasPrefix "/home/" cfg.dataDir then "false" else "strict";
        # Disable ProtectHome entirely when dataDir is in /home (required for access)
        ProtectHome = if lib.hasPrefix "/home/" cfg.dataDir then false else true;
        ReadWritePaths = [ cfg.dataDir ];
      };
    };

    # ----------------------------------------------------------------------------
    # NGINX REVERSE PROXY - Only configured if domain is set
    # ----------------------------------------------------------------------------
    services.nginx = lib.mkIf (cfg.domain != null) {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts.${cfg.domain} = {
        locations."/" = {
          proxyPass = "http://${cfg.bindIP}:${toString cfg.port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };

        forceSSL = cfg.enableSSL;
        enableACME = cfg.enableSSL;
      };
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      # Open Homepage port if not using reverse proxy or binding to non-localhost
      lib.optionals (cfg.domain == null && cfg.bindIP != "127.0.0.1") [ cfg.port ]
      # Open HTTP/HTTPS if using reverse proxy
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );
  };
}

/*
================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration:
----------------------
services.homepage-custom = {
  enable = true;
};
# Access at: http://localhost:3000


Network access without domain:
-------------------------------
services.homepage-custom = {
  enable = true;
  bindIP = "0.0.0.0";
  openFirewall = true;
};
# Access at: http://your-ip:3000


Configuration with home directory:
-----------------------------------
services.homepage-custom = {
  enable = true;
  dataDir = "/home/temhr/shelf/data/homepage";
};
# ProtectHome will automatically be disabled for home directory paths


Full configuration with domain:
--------------------------------
services.homepage-custom = {
  enable = true;
  port = 3000;
  bindIP = "127.0.0.1";
  dataDir = "/data/homepage";

  # Host validation (add all ways you'll access it)
  allowedHosts = [ "home.example.com" "localhost" "192.168.1.100" ];

  # Nginx reverse proxy
  domain = "home.example.com";
  enableSSL = true;
  openFirewall = true;
};


================================================================================
HOST VALIDATION
================================================================================

Homepage validates the Host header for security. If you get "Host validation
failed" errors, add the hostname/IP to allowedHosts:

  allowedHosts = [
    "localhost"
    "127.0.0.1"
    "192.168.1.100"
    "home.example.com"
  ];

Or disable validation entirely (not recommended):
  allowedHosts = [ "*" ];


================================================================================
CONFIGURATION
================================================================================

Homepage stores config in YAML files under dataDir/config/:
- services.yaml  - Dashboard services/links
- widgets.yaml   - Dashboard widgets
- bookmarks.yaml - Quick links
- settings.yaml  - General settings

Edit these files manually or use the built-in editor (if enabled).

Example services.yaml:
  - Group 1:
      - Service 1:
          href: http://example.com
          description: My service

Restart after config changes:
  sudo systemctl restart homepage


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status homepage

View logs:
  sudo journalctl -u homepage -f

Host validation error:
  Add your IP/hostname to allowedHosts

Cannot access from network:
  Set bindIP = "0.0.0.0" and openFirewall = true

Check config files:
  ls -la /var/lib/homepage/config/

Service fails with home directory:
  The fix automatically disables ProtectHome when dataDir is in /home/
  Make sure the homepage user has proper permissions to the directory
*/
