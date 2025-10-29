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

      # Storage configuration
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/wiki-js";
        example = "/data/wiki-js";
        description = "Directory for Wiki.js data and uploads";
      };

      uploadsPath = lib.mkOption {
        type = lib.types.path;
        default = "${cfg.dataDir}/data/uploads";
        defaultText = lib.literalExpression ''"''${config.wikijs.dataDir}/data/uploads"'';
        example = "/mnt/storage/wiki-uploads";
        description = "Path where uploaded files will be stored";
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

      # Set custom state directory
      stateDirectoryName = lib.mkIf (cfg.dataDir != "/var/lib/wiki-js")
        (lib.removePrefix "/var/lib/" cfg.dataDir);

      settings = {
        port = cfg.port;
        bindIP = cfg.bindIP;

        db = {
          type = "postgres";
          host = "/run/postgresql";
          db = "wiki-js";
          user = "wiki-js";
        };

        # Configure data paths
        dataPath = "${cfg.dataDir}/data";

        # Upload storage configuration
        uploads = {
          maxFileSize = 5242880;  # 5MB default
          maxFiles = 10;
        };

        logLevel = "info";
        ha = false;
      };
    };

    # Ensure proper service ordering and configuration
    systemd.services.wiki-js = {
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];

      # Override the state directory if custom path is set
      serviceConfig = lib.mkIf (cfg.dataDir != "/var/lib/wiki-js") {
        StateDirectory = lib.mkForce "";
        WorkingDirectory = cfg.dataDir;
      };

      # Ensure directories exist before starting
      preStart = ''
        mkdir -p ${cfg.uploadsPath}
        chown -R wiki-js:wiki-js ${cfg.dataDir}
      '';

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";

        # Bind mount for uploads if different from dataDir
        ${lib.optionalString (cfg.uploadsPath != "${cfg.dataDir}/data/uploads") ''
          BindPaths = "${cfg.uploadsPath}:${cfg.dataDir}/data/uploads"
        ''}
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
    networking.firewall.allowedTCPPorts = lib.mkIf (cfg.domain != null) [ 80 443 ];

    # Automatic PostgreSQL backups
    services.postgresqlBackup = lib.mkIf (cfg.backupPath != null) {
      enable = true;
      databases = [ "wiki-js" ];
      location = cfg.backupPath;
      startAt = cfg.backupSchedule;
      compression = "zstd";  # Better compression than gzip

      # Keep last 7 daily backups
      backupOptions = [
        "--create"
        "--clean"
        "--if-exists"
      ];
    };
  };
}

/*

  wikijs = {
    enable = true;
    port = 3000;
    bindIP = "127.0.0.1";

    dataDir = "/var/lib/wiki-js";                                 # Application data on SSD
    uploadsPath = "/home/temhr/shelf/wiki-js/wiki-uploads";   # Large files on HDD
    backupPath = "/home/temhr/shelf/wiki-js/backup";          # Backups on separate disk
    backupSchedule = "02:30";                                 # Run at 2:30 AM

    domain = "wiki.example.com";  # Optional
    enableSSL = true;              # Optional
  };

*/
