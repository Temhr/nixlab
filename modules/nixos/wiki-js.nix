{ config, lib, pkgs, ... }:

let
  cfg = config.services.wikijs-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.wikijs-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Wiki.js service";

      # OPTIONAL: Port to listen on (default: 3000)
      port = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = "Port for Wiki.js to listen on";
      };

      # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
      };

      # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "wiki.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      # Only works if domain is set
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      # OPTIONAL: Where to store Wiki.js data (default: /var/lib/wikijs)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/wikijs";
        example = "/data/wikijs";
        description = "Directory for Wiki.js data and configuration";
      };

      # OPTIONAL: Database type (default: sqlite)
      databaseType = lib.mkOption {
        type = lib.types.enum [ "sqlite" "postgres" "mysql" "mariadb" "mssql" ];
        default = "sqlite";
        description = "Database type to use";
      };

      # OPTIONAL: Database host (only for non-sqlite databases)
      databaseHost = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        description = "Database host (ignored for SQLite)";
      };

      # OPTIONAL: Database port
      databasePort = lib.mkOption {
        type = lib.types.port;
        default = 5432;
        description = "Database port (ignored for SQLite)";
      };

      # OPTIONAL: Database name
      databaseName = lib.mkOption {
        type = lib.types.str;
        default = "wikijs";
        description = "Database name (for SQLite: filename without extension)";
      };

      # OPTIONAL: Database user
      databaseUser = lib.mkOption {
        type = lib.types.str;
        default = "wikijs";
        description = "Database user (ignored for SQLite)";
      };

      # OPTIONAL: Database password file (for security)
      databasePasswordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/run/secrets/wikijs-db-password";
        description = "File containing database password (ignored for SQLite)";
      };

      # OPTIONAL: Wiki.js package to use (default: pkgs.wiki-js)
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.wiki-js;
        defaultText = lib.literalExpression "pkgs.wiki-js";
        description = "The Wiki.js package to use";
      };

      # OPTIONAL: Auto-open firewall ports (default: true)
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports";
      };

      # OPTIONAL: Enable automatic PostgreSQL database setup
      autoSetupPostgres = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatically setup PostgreSQL database and user";
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # ----------------------------------------------------------------------------
    # ASSERTIONS - Validate configuration
    # ----------------------------------------------------------------------------
    assertions = [
      {
        assertion = cfg.enableSSL -> cfg.domain != null;
        message = "services.wikijs-custom.enableSSL requires services.wikijs-custom.domain to be set";
      }
      {
        assertion = cfg.autoSetupPostgres -> cfg.databaseType == "postgres";
        message = "services.wikijs-custom.autoSetupPostgres requires databaseType to be postgres";
      }
    ];

    # ----------------------------------------------------------------------------
    # DIRECTORY SETUP - Create necessary directories with proper permissions
    # ----------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0770 wikijs wikijs -"
      "d ${cfg.dataDir}/data 0770 wikijs wikijs -"
    ];

    # ----------------------------------------------------------------------------
    # USER SETUP - Create dedicated system user for Wiki.js
    # ----------------------------------------------------------------------------
    users.users.wikijs = {
      isSystemUser = true;
      group = "wikijs";
      home = cfg.dataDir;
      description = "Wiki.js service user";
    };

    users.groups.wikijs = {};
    users.users.temhr.extraGroups = [ "wikijs" ];

    # ----------------------------------------------------------------------------
    # POSTGRESQL SETUP - Optional automatic database configuration
    # ----------------------------------------------------------------------------
    services.postgresql = lib.mkIf cfg.autoSetupPostgres {
      enable = true;
      ensureDatabases = [ cfg.databaseName ];
      ensureUsers = [{
        name = cfg.databaseUser;
        ensureDBOwnership = true;
      }];
    };

    # ----------------------------------------------------------------------------
    # WIKI.JS SERVICE - Configure the systemd service
    # ----------------------------------------------------------------------------
    systemd.services.wikijs = {
      description = "Wiki.js";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ]
        ++ lib.optionals cfg.autoSetupPostgres [ "postgresql.service" ];
      requires = lib.optionals cfg.autoSetupPostgres [ "postgresql.service" ];

      environment = {
        NODE_ENV = "production";
        WIKI_HOST = cfg.bindIP;
        WIKI_PORT = toString cfg.port;
        CONFIG_FILE = "${cfg.dataDir}/config.yml";
      };

      serviceConfig = {
        Type = "simple";
        User = "wikijs";
        Group = "wikijs";

        # IMPORTANT: Pre-start must not fail due to missing directory
        WorkingDirectory = "${cfg.dataDir}";

        ExecStart = "${pkgs.nodejs}/bin/node ${pkgs.wikijs}/share/wikijs/server";
        Restart = "on-failure";
        RestartSec = "10s";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];

        EnvironmentFile = lib.mkIf (cfg.databasePasswordFile != null)
          cfg.databasePasswordFile;
      };

      preStart = let
        wikiConfigJSON = {
          bindIP = cfg.bindIP;
          port = cfg.port;

          db = if cfg.databaseType == "sqlite" then {
            type = "sqlite";
            storage = "${cfg.dataDir}/data/${cfg.databaseName}.db";
          } else {
            type = "postgres";
            host = cfg.databaseHost;
            port = cfg.databasePort;
            user = cfg.databaseUser;
            #pass = cfg.databasePassword;  # optional
            db = cfg.databaseName;
            ssl = false;
          };

          logLevel = "info";
          dataPath = "${cfg.dataDir}/data";
        };
      in ''
        # Ensure directories exist
        mkdir -p ${cfg.dataDir}/data
        mkdir -p ${cfg.dataDir}/app

        # Symlink the full Wiki.js package to app/
        ln -sfn ${cfg.package}/* ${cfg.dataDir}/app/

        # Write JSON config
        cat > ${cfg.dataDir}/config.json <<'EOF'
${builtins.toJSON wikiConfigJSON}
EOF

        # Convert JSON → YAML
        ${pkgs.yq-go}/bin/yq -P ${cfg.dataDir}/config.json > ${cfg.dataDir}/config.yml

        chown wikijs:wikijs ${cfg.dataDir}/config.yml
        chmod 640 ${cfg.dataDir}/config.yml
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
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_redirect off;

            # Increase buffer sizes for Wiki.js
            proxy_buffer_size 128k;
            proxy_buffers 4 256k;
            proxy_busy_buffers_size 256k;

            # Increase timeout for long operations
            proxy_connect_timeout 600s;
            proxy_send_timeout 600s;
            proxy_read_timeout 600s;
          '';
        };
      };
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      # Open Wiki.js port if not using reverse proxy
      lib.optionals (cfg.domain == null) [ cfg.port ]
      # Open HTTP/HTTPS if using reverse proxy
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );
  };
}

/*
================================================================================
USAGE EXAMPLES
================================================================================

Minimal configuration (SQLite):
--------------------------------
services.wikijs-custom = {
  enable = true;
};
# Access at: http://your-ip:3000
# Complete setup wizard in browser


With PostgreSQL (manual setup):
--------------------------------
services.wikijs-custom = {
  enable = true;
  databaseType = "postgres";
  databaseHost = "localhost";
  databaseUser = "wikijs";
  databaseName = "wikijs";
  databasePasswordFile = "/run/secrets/wikijs-db-password";
};

# Create password file:
echo "your-secure-password" | sudo tee /run/secrets/wikijs-db-password
sudo chmod 600 /run/secrets/wikijs-db-password


With PostgreSQL (automatic setup):
-----------------------------------
services.wikijs-custom = {
  enable = true;
  databaseType = "postgres";
  autoSetupPostgres = true;
};
# PostgreSQL database and user created automatically
# Uses peer authentication (no password needed)


Full configuration with domain:
--------------------------------
services.wikijs-custom = {
  enable = true;
  port = 3000;
  bindIP = "0.0.0.0";
  dataDir = "/data/wikijs";

  # Database
  databaseType = "postgres";
  autoSetupPostgres = true;

  # Nginx reverse proxy
  domain = "wiki.example.com";
  enableSSL = true;
  openFirewall = true;
};


================================================================================
CONFIGURATION
================================================================================

Wiki.js configuration is stored in config.yml in dataDir.
A default config is created automatically on first run.

Edit configuration:
  sudo nano /var/lib/wikijs/config.yml
  sudo systemctl restart wikijs

On first access via web browser, complete the setup wizard:
  1. Create administrator account
  2. Configure site settings
  3. Set up authentication providers
  4. Choose storage targets (local, git, S3, etc.)


================================================================================
DATABASE SETUP
================================================================================

SQLite (default):
  - No setup required
  - Database file: /var/lib/wikijs/data/wikijs.db
  - Good for small wikis (<10 concurrent users)

PostgreSQL (recommended for production):
  - Option 1: Use autoSetupPostgres = true
  - Option 2: Manual setup:

    sudo -u postgres psql
    CREATE DATABASE wikijs;
    CREATE USER wikijs WITH PASSWORD 'your-password';
    GRANT ALL PRIVILEGES ON DATABASE wikijs TO wikijs;
    \q

MySQL/MariaDB:
  - Install MySQL/MariaDB separately
  - Create database and user manually
  - Set databaseType = "mysql" or "mariadb"


================================================================================
BACKUP AND RESTORE
================================================================================

Backup:
  sudo systemctl stop wikijs
  sudo tar -czf wikijs-backup.tar.gz /var/lib/wikijs
  sudo systemctl start wikijs

Restore:
  sudo systemctl stop wikijs
  sudo tar -xzf wikijs-backup.tar.gz -C /
  sudo systemctl start wikijs


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status wikijs

View logs:
  sudo journalctl -u wikijs -f

Edit configuration:
  sudo nano /var/lib/wikijs/config.yml
  sudo systemctl restart wikijs

Database connection issues:
  - Verify database is running
  - Check credentials in config.yml
  - For PostgreSQL: ensure user has proper permissions

Port already in use:
  - Check what's using the port: sudo ss -tulpn | grep :3000
  - Change port in module configuration

Can't access via domain:
  - Verify nginx is running: sudo systemctl status nginx
  - Check DNS records point to your server
  - Review nginx logs: sudo journalctl -u nginx -f

Setup wizard shows error:
  - Check file permissions: ls -la /var/lib/wikijs
  - Verify database connectivity
  - Check logs for specific error messages

Reset admin password:
  # Connect to database and run Wiki.js CLI commands
  # See: https://docs.js.wiki/admin/password-reset

*/
