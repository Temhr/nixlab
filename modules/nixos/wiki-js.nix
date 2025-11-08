{ config, lib, pkgs, ... }:

let
  cfg = config.wikijs;
in
{
  options = {
    wikijs = {
      enable = lib.mkEnableOption "Wiki.js service";

      port = lib.mkOption {
        type = lib.types.port;
        default = 3001;
        description = "Port for Wiki.js to listen on";
      };

      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1"; #localhost only
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

      # Storage configuration
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/wiki-js";
        example = "/data/wiki-js";
        description = "Directory for Wiki.js data and uploads";
      };

      uploadsPath = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/mnt/storage/wiki-uploads";
        description = "Path where uploaded files will be stored (null uses default under dataDir)";
      };

      backupPath = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/backup/wiki-js";
        description = "Path for automatic PostgreSQL backups (null disables backups)";
      };

      backupSchedule = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        example = "02:00";
        description = "Backup schedule (systemd time format)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Create necessary directories
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 wiki-js wiki-js -"
    ] ++ lib.optionals (cfg.uploadsPath != null) [
      "d ${cfg.uploadsPath} 0750 wiki-js wiki-js -"
    ] ++ lib.optionals (cfg.backupPath != null) [
      "d ${cfg.backupPath} 0750 postgres postgres -"
    ];

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

      # Override state directory if using custom path
      stateDirectoryName = lib.mkIf (cfg.dataDir != "/var/lib/wiki-js")
        (baseNameOf cfg.dataDir);

      settings = {
        port = cfg.port;
        bindIP = cfg.bindIP;

        db = {
          type = "postgres";
          host = "/run/postgresql";
          db = "wiki-js";
          user = "wiki-js";
        };

        # Don't override dataPath - let the module handle it
        # The module sets this based on stateDirectoryName

        logLevel = "info";
        ha = false;
      };
    };

    # Ensure proper service ordering and configuration
    systemd.services.wiki-js = {
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];

      # Add custom preStart if we have a custom uploads path
      preStart = lib.mkIf (cfg.uploadsPath != null) (lib.mkAfter ''
        # Ensure uploads directory exists and is properly linked
        mkdir -p ${cfg.uploadsPath}

        # Create symlink from default location to custom uploads path
        if [ ! -L "${cfg.dataDir}/data/uploads" ]; then
          rm -rf "${cfg.dataDir}/data/uploads"
          ln -sf ${cfg.uploadsPath} "${cfg.dataDir}/data/uploads"
        fi

        chown -R wiki-js:wiki-js ${cfg.uploadsPath}
      '');

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";
      } // lib.optionalAttrs (cfg.dataDir != "/var/lib/wiki-js") {
        # Override the state directory location
        StateDirectory = lib.mkForce "";
        WorkingDirectory = lib.mkForce cfg.dataDir;
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

            # Increase upload size limit
            client_max_body_size 50M;
          '';
        };

        forceSSL = cfg.enableSSL;
        enableACME = cfg.enableSSL;
      };
    };

    # Firewall configuration
    networking.firewall.allowedTCPPorts = [ 80 443 3001 ];

    # Automatic PostgreSQL backups
    services.postgresqlBackup = lib.mkIf (cfg.backupPath != null) {
      enable = true;
      databases = [ "wiki-js" ];
      location = cfg.backupPath;
      startAt = cfg.backupSchedule;
      compression = "zstd";
    };
  };
}

/*

  wikijs = {
    enable = true;
    port = 3001;
    bindIP = "127.0.0.1";

    # Custom data directory
    dataDir = "/data/wiki-js";

    # Optional: Custom uploads directory (creates symlink)
    uploadsPath = "/mnt/storage/wiki-uploads";

    # Optional: Backups
    backupPath = "/backup/wiki-js";
    backupSchedule = "02:30";

    # Optional: Nginx reverse proxy
    domain = "wiki.example.com";  # Optional
    enableSSL = true;              # Optional
  };

*/
