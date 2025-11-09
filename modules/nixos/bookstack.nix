{ config, lib, pkgs, ... }:

let
  cfg = config.services.bookstack;
in
{
  options = {
    services.bookstack = {
      enable = lib.mkEnableOption "BookStack service";

      port = lib.mkOption {
        type = lib.types.port;
        default = 3002;
        description = "Port for BookStack to listen on";
      };

      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0"; # localhost only
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

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/bookstack";
        example = "/data/bookstack";
        description = "Directory for BookStack data and uploads";
      };

      appURL = lib.mkOption {
        type = lib.types.str;
        default = "http://localhost:${toString cfg.port}";
        example = "https://wiki.example.com";
        description = "Full URL where BookStack will be accessible";
      };

      appKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Application key for encryption (auto-generated if null)";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.bookstack;
        defaultText = lib.literalExpression "pkgs.bookstack";
        description = "The BookStack package to use";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open firewall ports for HTTP/HTTPS";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Create necessary directories
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 bookstack bookstack -"
      "d ${cfg.dataDir}/public/uploads 0750 bookstack bookstack -"
      "d ${cfg.dataDir}/storage 0750 bookstack bookstack -"
    ];

    # Create bookstack user
    users.users.bookstack = {
      isSystemUser = true;
      group = "bookstack";
      home = cfg.dataDir;
    };

    users.groups.bookstack = {};

    # MySQL/MariaDB configuration
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = [ "bookstack" ];
      ensureUsers = [{
        name = "bookstack";
        ensurePermissions = {
          "bookstack.*" = "ALL PRIVILEGES";
        };
      }];
    };

    # BookStack service
    systemd.services.bookstack = {
      description = "BookStack Documentation Platform";
      wantedBy = [ "multi-user.target" ];
      requires = [ "mysql.service" ];
      after = [ "network.target" "mysql.service" ];

      environment = {
        APP_URL = cfg.appURL;
        DB_HOST = "localhost";
        DB_DATABASE = "bookstack";
        DB_USERNAME = "bookstack";
        DB_PASSWORD = "";
        STORAGE_TYPE = "local";
        STORAGE_LOCAL_ROOT = "${cfg.dataDir}/storage";
      };

      serviceConfig = {
        Type = "simple";
        User = "bookstack";
        Group = "bookstack";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/bookstack-server --host ${cfg.bindIP} --port ${toString cfg.port}";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };

      preStart = ''
        # Generate app key if not provided
        if [ ! -f ${cfg.dataDir}/.app_key ]; then
          echo "base64:$(openssl rand -base64 32)" > ${cfg.dataDir}/.app_key
          chown bookstack:bookstack ${cfg.dataDir}/.app_key
          chmod 600 ${cfg.dataDir}/.app_key
        fi
      '';
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

            # Increase upload size limit
            client_max_body_size 50M;
          '';
        };

        forceSSL = cfg.enableSSL;
        enableACME = cfg.enableSSL;
      };
    };

    # Firewall configuration
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ 80 443 3002 ];
  };
}

/*
Usage example:

services.bookstack = {
  enable = true;
  port = 3002;
  bindIP = "0.0.0.0";

  # Set the URL where BookStack will be accessible
  appURL = "https://wiki.example.com";

  # Custom data directory (optional)
  dataDir = "/data/bookstack";

  # Optional: Nginx reverse proxy
  domain = "wiki.example.com";
  enableSSL = true;
  openFirewall = true;
};

# Default credentials (change immediately):
# Email: admin@admin.com
# Password: password
*/
