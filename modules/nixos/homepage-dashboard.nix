{ config, lib, pkgs, ... }:

let
  cfg = config.services.homepage;
in
{
  options = {
    services.homepage = {
      enable = lib.mkEnableOption "Homepage service";

      port = lib.mkOption {
        type = lib.types.port;
        default = 3000 ;
        description = "Port for Homepage to listen on";
      };

      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1"; # localhost only
        description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "home.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/homepage";
        example = "/data/homepage";
        description = "Directory for Homepage configuration and data";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.homepage-dashboard;
        defaultText = lib.literalExpression "pkgs.homepage-dashboard";
        description = "The Homepage package to use";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Create necessary directories
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 homepage homepage -"
      "d ${cfg.dataDir}/config 0750 homepage homepage -"
    ];

    # Create homepage user
    users.users.homepage = {
      isSystemUser = true;
      group = "homepage";
      home = cfg.dataDir;
    };

    users.groups.homepage = {};

    # Homepage service
    systemd.services.homepage = {
      description = "Homepage Dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        HOMEPAGE_CONFIG_DIR = "${cfg.dataDir}/config";
        PORT = toString cfg.port;
        HOSTNAME = cfg.bindIP;
      };

      serviceConfig = {
        Type = "simple";
        User = "homepage";
        Group = "homepage";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/homepage";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
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

    # Firewall configuration
    networking.firewall.allowedTCPPorts = [ 80 443 3000 ];
  };
}

/*
Usage example:

services.homepage = {
  enable = true;
  port = 3000;
  bindIP = "127.0.0.1";

  # Custom data directory (optional)
  dataDir = "/data/homepage";

  # Optional: Nginx reverse proxy
  domain = "home.example.com";
  enableSSL = true;
};
*/
