{ config, lib, pkgs, ... }:

let
  cfg = config.wikijs;
in
{
  options = {
    wikijs = {
      enable = lib.mkEnableOption "Wiki.js service";

      # Add more configurable options
      port = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = "Port for Wiki.js to listen on";
      };

      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "wiki.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # PostgreSQL configuration
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "wiki-js" ];
      ensureUsers = [{
        name = "wiki-js";
        ensureDBOwnership = true;
      }];
    };

    # Wiki.js service configuration
    services.wiki-js = {
      enable = true;
      settings = {
        port = cfg.port;
        bindIP = cfg.bindIP;

        db = {
          type = "postgres";
          host = "/run/postgresql";  # Unix socket - more secure and faster
          db = "wiki-js";
          user = "wiki-js";
        };

        # Additional recommended settings
        logLevel = "info";
        ha = false;  # High availability mode (set to true if using multiple instances)
      };
    };

    # Ensure proper service ordering
    systemd.services.wiki-js = {
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];

      # Add service hardening
      serviceConfig = {
        # Restart policy
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening (optional but recommended)
        # NoNewPrivileges = true;
        # PrivateTmp = true;
        # ProtectSystem = "strict";
        # ProtectHome = true;
      };
    };

    # Optional: Nginx reverse proxy
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

    # Open firewall if nginx is enabled
    networking.firewall.allowedTCPPorts = lib.mkIf (cfg.domain != null) [ 80 443 ];

    # Optional: Automatic backup configuration
    # Uncomment and customize as needed
    # services.postgresqlBackup = {
    #   enable = true;
    #   databases = [ "wiki-js" ];
    #   location = "/var/backup/postgresql";
    #   startAt = "daily";
    # };
  };
}
