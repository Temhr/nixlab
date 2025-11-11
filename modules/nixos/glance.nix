{ config, lib, pkgs, ... }:

let
  cfg = config.services.glance-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.glance-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Glance dashboard service";

      # OPTIONAL: Port to listen on (default: 3004)
      port = lib.mkOption {
        type = lib.types.port;
        default = 3004;
        description = "Port for Glance to listen on";
      };

      # OPTIONAL: IP to bind to (default: 0.0.0.0 = all interfaces)
      # Glance is typically accessed from network
      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "IP address to bind to";
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

      # OPTIONAL: Auto-open firewall ports (default: true)
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports";
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
      "d ${cfg.dataDir} 0770 glance glance -"
    ];

    # ----------------------------------------------------------------------------
    # USER SETUP - Create dedicated system user for Glance
    # ----------------------------------------------------------------------------
    users.users.glance = {
      isSystemUser = true;
      group = "glance";
      home = cfg.dataDir;
      createHome = true;
      description = "Glance dashboard user";
    };

    users.groups.glance = {};
    users.users.temhr.extraGroups = [ "glance" ];

    # ----------------------------------------------------------------------------
    # GLANCE SERVICE - Configure the systemd service
    # ----------------------------------------------------------------------------
    systemd.services.glance = {
      description = "Glance Dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "glance";
        Group = "glance";
        WorkingDirectory = cfg.dataDir;
        # Glance looks for glance.yml in current directory
        ExecStart = "${cfg.package}/bin/glance --bind ${cfg.bindIP}:${toString cfg.port}";
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
        if [ ! -f ${cfg.dataDir}/glance.yml ]; then
          cat > ${cfg.dataDir}/glance.yml << 'EOF'
pages:
  - name: Home
    columns:
      - size: small
        widgets:
          - type: clock
            hour-format: 24h

          - type: calendar

      - size: full
        widgets:
          - type: rss
            limit: 10
            collapse-after: 3
            cache: 3h
            feeds:
              - url: https://news.ycombinator.com/rss
                title: Hacker News
EOF
          chown glance:glance ${cfg.dataDir}/glance.yml
          chmod 640 ${cfg.dataDir}/glance.yml
        fi
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
          proxyPass = "http://${cfg.bindIP}:${toString cfg.port}";
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
      # Open Glance port if not using reverse proxy
      lib.optionals (cfg.domain == null) [ cfg.port ]
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
services.glance-custom = {
  enable = true;
};
# Access at: http://your-ip:3004


Full configuration with domain:
--------------------------------
services.glance-custom = {
  enable = true;
  port = 3004;
  bindIP = "0.0.0.0";
  dataDir = "/data/glance";

  # Nginx reverse proxy
  domain = "dashboard.example.com";
  enableSSL = true;
  openFirewall = true;
};


================================================================================
CONFIGURATION
================================================================================

Glance reads configuration from glance.yml in dataDir.
A default config is created automatically on first run.

Edit configuration:
  sudo nano /var/lib/glance/glance.yml
  sudo systemctl restart glance

Example glance.yml:
  pages:
    - name: Home
      columns:
        - size: small
          widgets:
            - type: clock
            - type: weather
              location: New York
        - size: full
          widgets:
            - type: rss
              feeds:
                - url: https://example.com/feed
                  title: My Feed

Available widgets:
  - clock, calendar, weather
  - rss, reddit, hacker-news
  - monitor (server monitoring)
  - stocks, markets
  - videos (YouTube)
  - bookmarks, iframe


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status glance

View logs:
  sudo journalctl -u glance -f

Edit configuration:
  sudo nano /var/lib/glance/glance.yml
  sudo systemctl restart glance

Config syntax errors:
  ${pkgs.glance}/bin/glance --config /var/lib/glance/glance.yml --check

*/
