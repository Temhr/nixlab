{ config, lib, pkgs, ... }:

let
  cfg = config.services.zola-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.zola-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Zola static site server";

      # OPTIONAL: Port to listen on (default: 3003)
      port = lib.mkOption {
        type = lib.types.port;
        default = 3003;
        description = "Port for Zola to serve on";
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
        example = "blog.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      # Only works if domain is set
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      # REQUIRED: Path to your Zola site directory
      # This should contain config.toml and content/
      siteDir = lib.mkOption {
        type = lib.types.path;
        example = "/var/www/my-blog";
        description = "Path to Zola site directory (must contain config.toml)";
      };

      # OPTIONAL: Zola package to use (default: pkgs.zola)
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.zola;
        defaultText = lib.literalExpression "pkgs.zola";
        description = "The Zola package to use";
      };

      # OPTIONAL: Auto-rebuild site on changes (default: true)
      # When enabled, watches for file changes and rebuilds automatically
      watchMode = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable watch mode to rebuild on file changes";
      };

      # OPTIONAL: Auto-open firewall ports (default: false)
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open firewall ports";
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # ----------------------------------------------------------------------------
    # USER SETUP - Create dedicated system user for Zola
    # ----------------------------------------------------------------------------
    users.users.zola = {
      isSystemUser = true;
      group = "zola";
      description = "Zola static site server user";
    };

    users.groups.zola = {};
    users.users.temhr.extraGroups = [ "zola" ];

    # ----------------------------------------------------------------------------
    # ZOLA SERVICE - Configure the systemd service
    # ----------------------------------------------------------------------------
    systemd.services.zola = {
      description = "Zola Static Site Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      # Validate site directory before starting
      preStart = ''
        if [ ! -f ${cfg.siteDir}/config.toml ]; then
          echo "ERROR: Zola site not found at ${cfg.siteDir}"
          echo "Please create a Zola site first: zola init ${cfg.siteDir}"
          exit 1
        fi
      '';

      serviceConfig = {
        Type = "simple";
        User = "zola";
        Group = "zola";
        WorkingDirectory = cfg.siteDir;
        # Start Zola server with watch mode or static serve
        ExecStart = if cfg.watchMode
                    then "${cfg.package}/bin/zola serve --interface ${cfg.bindIP} --port ${toString cfg.port} --base-url http://${cfg.bindIP}:${toString cfg.port}"
                    else "${cfg.package}/bin/zola serve --interface ${cfg.bindIP} --port ${toString cfg.port} --base-url http://${cfg.bindIP}:${toString cfg.port} --watch-only";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadOnlyPaths = [ cfg.siteDir ];
      };
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
      # Open Zola port if not using reverse proxy or binding to non-localhost
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
services.zola-custom = {
  enable = true;
  siteDir = "/var/www/my-blog";  # REQUIRED
};
# Access at: http://localhost:3003


Network access:
---------------
services.zola-custom = {
  enable = true;
  siteDir = "/var/www/my-blog";
  bindIP = "0.0.0.0";
  openFirewall = true;
};
# Access at: http://your-ip:3003


Full configuration with domain:
--------------------------------
services.zola-custom = {
  enable = true;
  siteDir = "/var/www/my-blog";
  port = 3003;
  bindIP = "127.0.0.1";
  watchMode = true;  # Auto-rebuild on changes

  # Nginx reverse proxy
  domain = "blog.example.com";
  enableSSL = true;
  openFirewall = true;
};


================================================================================
ZOLA SITE STRUCTURE
================================================================================

Your siteDir must contain:
  config.toml    - Site configuration
  content/       - Markdown content files
  templates/     - HTML templates
  static/        - Static files (images, CSS, JS)
  themes/        - Themes (optional)

Create a new Zola site:
  zola init /var/www/my-blog
  cd /var/www/my-blog
  # Edit config.toml and add content

Build site manually (not needed with service):
  zola build


================================================================================
WATCH MODE
================================================================================

watchMode = true (default):
  - Automatically rebuilds site when files change
  - Good for: Development, content updates

watchMode = false:
  - Only serves pre-built site
  - Good for: Production, static deployments
  - Run 'zola build' manually when updating


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status zola

View logs:
  sudo journalctl -u zola -f

Manually test Zola:
  cd /var/www/my-blog
  zola serve

Check site structure:
  zola check

Build errors:
  zola build --verbose

*/
