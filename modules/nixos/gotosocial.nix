{ config, lib, pkgs, ... }:

let
  cfg = config.services.gotosocial-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.gotosocial-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "GoToSocial federated social media server";

      # OPTIONAL: Port to listen on (default: 3005)
      port = lib.mkOption {
        type = lib.types.port;
        default = 3005;
        description = "Port for GoToSocial to listen on";
      };

      # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
      # GoToSocial is typically accessed through reverse proxy
      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address to bind to";
      };

      # REQUIRED: Domain for your instance
      domain = lib.mkOption {
        type = lib.types.str;
        example = "social.example.com";
        description = "Domain name for your GoToSocial instance";
      };

      # OPTIONAL: Account domain (default: same as domain)
      accountDomain = lib.mkOption {
        type = lib.types.str;
        default = cfg.domain;
        defaultText = lib.literalExpression "config.services.gotosocial-custom.domain";
        example = "example.com";
        description = "Domain to use in account names (e.g., @user@example.com)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: true)
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable HTTPS with Let's Encrypt";
      };

      # OPTIONAL: Where to store GoToSocial data (default: /var/lib/gotosocial)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/gotosocial";
        example = "/data/gotosocial";
        description = "Directory for GoToSocial data and configuration";
      };

      # OPTIONAL: GoToSocial package to use (default: pkgs.gotosocial)
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.gotosocial;
        defaultText = lib.literalExpression "pkgs.gotosocial";
        description = "The GoToSocial package to use";
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
    # DIRECTORY SETUP - Create necessary directories with proper permissions
    # ----------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0770 gotosocial gotosocial -"
      "d ${cfg.dataDir}/storage 0770 gotosocial gotosocial -"
    ];

    # ----------------------------------------------------------------------------
    # USER SETUP - Create dedicated system user for GoToSocial
    # ----------------------------------------------------------------------------
    users.users.gotosocial = {
      isSystemUser = true;
      group = "gotosocial";
      home = cfg.dataDir;
      description = "GoToSocial server user";
    };

    users.groups.gotosocial = {};

    # ----------------------------------------------------------------------------
    # GOTOSOCIAL SERVICE - Configure the systemd service
    # ----------------------------------------------------------------------------
    systemd.services.gotosocial = {
      description = "GoToSocial Federated Social Media Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "gotosocial";
        Group = "gotosocial";
        WorkingDirectory = cfg.dataDir;
        # GoToSocial reads config from config.yaml in current directory
        ExecStart = "${cfg.package}/bin/gotosocial --config-path ${cfg.dataDir}/config.yaml server start";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };

      # Ensure config file exists with proper permissions
      preStart = ''
        # Create default config if it doesn't exist
        if [ ! -f ${cfg.dataDir}/config.yaml ]; then
          cat > ${cfg.dataDir}/config.yaml << EOF
# GoToSocial Configuration
# See: https://docs.gotosocial.org/en/latest/configuration/

# Network configuration
host: "${cfg.domain}"
account-domain: "${cfg.accountDomain}"
protocol: "${if cfg.enableSSL then "https" else "http"}"
bind-address: "${cfg.bindIP}"
port: ${toString cfg.port}

# Database (SQLite by default)
db-type: "sqlite"
db-address: "${cfg.dataDir}/gotosocial.db"

# Storage
storage-backend: "local"
storage-local-base-path: "${cfg.dataDir}/storage"

# Media settings
media-image-max-size: 10485760  # 10MB
media-video-max-size: 41943040  # 40MB

# Instance settings
instance-languages:
  - en

# Accounts
accounts-registration-open: false
accounts-approval-required: true
accounts-reason-required: true

# Advanced settings
advanced-cookies-samesite: "lax"
advanced-rate-limit-requests: 300

# Logging
log-level: "info"
EOF
          chown gotosocial:gotosocial ${cfg.dataDir}/config.yaml
          chmod 660 ${cfg.dataDir}/config.yaml
        fi
      '';
    };

    # ----------------------------------------------------------------------------
    # NGINX REVERSE PROXY - Required for GoToSocial
    # ----------------------------------------------------------------------------
    services.nginx.enable = true;

    services.nginx.virtualHosts.${cfg.domain} = {
      forceSSL = cfg.enableSSL;
      enableACME = cfg.enableSSL;

      locations."/" = {
        proxyPass = "http://${cfg.bindIP}:${toString cfg.port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;

          # Required for GoToSocial
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";

          # Timeouts for large media uploads
          client_max_body_size 40M;
          proxy_read_timeout 300;
          proxy_connect_timeout 300;
          proxy_send_timeout 300;
        '';
      };
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ 80 443 ];
  };
}

/*
================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration:
----------------------
services.gotosocial-custom = {
  enable = true;
  domain = "social.example.com";
};
# Access at: https://social.example.com (after DNS is configured)


Full configuration:
-------------------
services.gotosocial-custom = {
  enable = true;
  port = 3005;
  bindIP = "127.0.0.1";
  domain = "social.example.com";
  accountDomain = "example.com";  # Users will be @user@example.com
  enableSSL = true;
  dataDir = "/data/gotosocial";
  openFirewall = true;
};


================================================================================
INITIAL SETUP
================================================================================

After first start, create an admin account:

1. Create admin user:
   sudo -u gotosocial ${pkgs.gotosocial}/bin/gotosocial \
     --config-path /var/lib/gotosocial/config.yaml \
     admin account create \
     --username admin \
     --email admin@example.com \
     --password 'YourSecurePassword'

2. Promote to admin:
   sudo -u gotosocial ${pkgs.gotosocial}/bin/gotosocial \
     --config-path /var/lib/gotosocial/config.yaml \
     admin account promote --username admin

3. Open registration (optional):
   Edit config.yaml and set:
     accounts-registration-open: true


================================================================================
CONFIGURATION
================================================================================

GoToSocial reads configuration from config.yaml in dataDir.
A default config is created automatically on first run.

Edit configuration:
  sudo nano /var/lib/gotosocial/config.yaml
  sudo systemctl restart gotosocial

Full configuration documentation:
  https://docs.gotosocial.org/en/latest/configuration/

Important settings:
  - accounts-registration-open: Allow new user signups
  - accounts-approval-required: Require admin approval
  - media-*-max-size: Maximum file sizes
  - instance-languages: Supported languages


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status gotosocial

View logs:
  sudo journalctl -u gotosocial -f

Edit configuration:
  sudo nano /var/lib/gotosocial/config.yaml
  sudo systemctl restart gotosocial

Admin CLI commands:
  sudo -u gotosocial ${pkgs.gotosocial}/bin/gotosocial \
    --config-path /var/lib/gotosocial/config.yaml admin --help

Common issues:
  - Ensure DNS points to your server
  - Ensure ports 80/443 are open
  - Check nginx configuration: sudo nginx -t
  - Verify Let's Encrypt certificates are obtained


================================================================================
FEDERATION
================================================================================

GoToSocial federates with other ActivityPub servers (Mastodon, Pleroma, etc.)

Important notes:
  - Domain cannot be changed after setup
  - Account domain affects how usernames appear
  - Federation requires HTTPS (enableSSL = true)
  - Allow outbound HTTPS connections in firewall

*/
