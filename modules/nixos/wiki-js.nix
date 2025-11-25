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

      # OPTIONAL: Port to listen on (default: 3001)
      port = lib.mkOption {
        type = lib.types.port;
        default = 3001;
        description = "Port for Wiki.js to listen on";
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

      # OPTIONAL: Where to store Wiki.js data (default: /var/lib/wiki-js)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/wiki-js";
        example = "/data/wiki-js";
        description = "Directory for Wiki.js data and configuration";
      };

      # OPTIONAL: Custom path for uploaded files (default: null = under dataDir)
      # Useful for storing uploads on a separate mount/drive
      uploadsPath = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/mnt/storage/wiki-uploads";
        description = "Path where uploaded files will be stored (null uses default under dataDir)";
      };

      # OPTIONAL: Path for PostgreSQL backups (default: null = no backups)
      backupPath = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/backup/wiki-js";
        description = "Path for automatic PostgreSQL backups (null disables backups)";
      };

      # OPTIONAL: Backup schedule (default: daily)
      # Uses systemd timer format (e.g., "daily", "weekly", "02:30")
      backupSchedule = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        example = "02:00";
        description = "Backup schedule (systemd time format)";
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
      # Create main data directory owned by wiki-js user
      "d ${cfg.dataDir} 0770 wiki-js wiki-js -"
    ]
    # Create custom uploads directory if specified
    ++ lib.optionals (cfg.uploadsPath != null) [
      "d ${cfg.uploadsPath} 0770 wiki-js wiki-js -"
    ]
    # Create backup directory if specified (owned by postgres user)
    ++ lib.optionals (cfg.backupPath != null) [
      "d ${cfg.backupPath} 0770 postgres postgres -"
    ];

    users.users.temhr.extraGroups = [ "postgres" "wiki-js" ];

    # ----------------------------------------------------------------------------
    # DATABASE SETUP - Wiki.js requires PostgreSQL
    # ----------------------------------------------------------------------------
    services.postgresql = {
      enable = true;
      # Create the 'wiki-js' database automatically
      ensureDatabases = [ "wiki-js" ];
      # Create 'wiki-js' user with ownership of the database
      ensureUsers = [{
        name = "wiki-js";
        ensureDBOwnership = true;
      }];
    };

    # ----------------------------------------------------------------------------
    # WIKI.JS SERVICE - Configure the built-in NixOS Wiki.js module
    # ----------------------------------------------------------------------------
    services.wiki-js = {
      enable = true;

      # Override state directory name if using custom path
      # This tells the module to use a different base directory
      stateDirectoryName = lib.mkIf (cfg.dataDir != "/var/lib/wiki-js")
        (baseNameOf cfg.dataDir);

      # Wiki.js application settings
      settings = {
        # Network configuration
        port = cfg.port;
        bindIP = cfg.bindIP;

        # Database configuration (PostgreSQL via Unix socket)
        db = {
          type = "postgres";
          host = "/run/postgresql";  # Unix socket connection
          db = "wiki-js";
          user = "wiki-js";
        };

        # Logging and high-availability settings
        logLevel = "info";
        ha = false;  # High availability mode disabled (single instance)
      };
    };

    # ----------------------------------------------------------------------------
    # SERVICE CUSTOMIZATION - Additional systemd service configuration
    # ----------------------------------------------------------------------------
    systemd.services.wiki-js = {
      # Ensure PostgreSQL is running before Wiki.js starts
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];

      # Custom preStart script for uploads directory (only if custom path specified)
      preStart = lib.mkIf (cfg.uploadsPath != null) (lib.mkAfter ''
        # Ensure uploads directory exists
        mkdir -p ${cfg.uploadsPath}

        # Create symlink from default location to custom uploads path
        if [ ! -L "${cfg.dataDir}/data/uploads" ]; then
          rm -rf "${cfg.dataDir}/data/uploads"
          ln -sf ${cfg.uploadsPath} "${cfg.dataDir}/data/uploads"
        fi

        # Ensure proper ownership
        chown -R wiki-js:wiki-js ${cfg.uploadsPath}
      '');

      serviceConfig = {
        # Restart on failure
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    # ----------------------------------------------------------------------------
    # NGINX REVERSE PROXY - Only configured if domain is set
    # ----------------------------------------------------------------------------
    services.nginx = lib.mkIf (cfg.domain != null) {
      enable = true;
      # Enable recommended security and performance settings
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts.${cfg.domain} = {
        # Proxy all requests to Wiki.js
        locations."/" = {
          proxyPass = "http://${cfg.bindIP}:${toString cfg.port}";
          # Enable WebSocket support (required for real-time collaboration)
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Increase upload size limit for file attachments
            client_max_body_size 50M;
          '';
        };

        # Force HTTPS if SSL is enabled
        forceSSL = cfg.enableSSL;
        # Get automatic SSL certificate from Let's Encrypt
        enableACME = cfg.enableSSL;
      };
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      # Open Wiki.js port if not using reverse proxy or binding to non-localhost
      lib.optionals (cfg.domain == null && cfg.bindIP != "127.0.0.1") [ cfg.port ]
      # Open HTTP/HTTPS if using reverse proxy
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );

    # ----------------------------------------------------------------------------
    # AUTOMATIC BACKUPS - PostgreSQL database backups (optional)
    # ----------------------------------------------------------------------------
    services.postgresqlBackup = lib.mkIf (cfg.backupPath != null) {
      enable = true;
      # Backup the wiki-js database
      databases = [ "wiki-js" ];
      # Store backups in specified location
      location = cfg.backupPath;
      # Schedule (e.g., "daily", "weekly", or specific time "02:30")
      startAt = cfg.backupSchedule;
      # Compress backups with zstd (good compression + speed)
      compression = "zstd";
    };
  };
}

/*
================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration (only required options):
----------------------------------------------
services.wikijs-custom = {
  enable = true;  # REQUIRED
};
# Runs on localhost:3001, no backups, no reverse proxy


Full configuration (all options):
----------------------------------
services.wikijs-custom = {
  enable = true;                # REQUIRED: Turn on the service
  port = 3001;                  # OPTIONAL: Default is 3001
  bindIP = "127.0.0.1";        # OPTIONAL: Default is 127.0.0.1
  dataDir = "/data/wiki-js";    # OPTIONAL: Default is /var/lib/wiki-js

  # OPTIONAL: Store uploads on separate storage
  uploadsPath = "/mnt/storage/wiki-uploads";

  # OPTIONAL: Enable automatic database backups
  backupPath = "/backup/wiki-js";
  backupSchedule = "02:30";     # Daily at 2:30 AM

  # OPTIONAL: Nginx reverse proxy with SSL
  domain = "wiki.example.com";  # Default is null (no proxy)
  enableSSL = true;             # Default is false
  openFirewall = true;          # Default is true
};


Network-accessible without reverse proxy:
------------------------------------------
services.wikijs-custom = {
  enable = true;
  port = 3001;
  bindIP = "0.0.0.0";          # Allow network access
  openFirewall = true;
};
# Access at: http://your-ip:3001


================================================================================
FIRST-TIME SETUP INSTRUCTIONS
================================================================================

Step 1: Apply your NixOS configuration
---------------------------------------
  sudo nixos-rebuild switch


Step 2: Access Wiki.js
-----------------------
Local access:      http://localhost:3001
Network access:    http://your-ip:3001 (if bindIP = "0.0.0.0")
Domain access:     https://wiki.example.com (if configured)


Step 3: Complete setup wizard
------------------------------
On first access, Wiki.js will guide you through:
1. Setting up administrator account
2. Configuring site settings
3. Choosing authentication methods
4. Selecting storage options


Step 4: Configure storage and authentication (optional)
--------------------------------------------------------
After initial setup, you can configure:
- Local storage or cloud storage (S3, Azure, etc.)
- Authentication providers (local, OAuth, LDAP, etc.)
- Search engines (database, elasticsearch, etc.)

All configuration is done through the web interface:
Administration → Storage/Authentication/Search


================================================================================
WHAT GETS INSTALLED
================================================================================

This module automatically sets up:
- ✓ Wiki.js application
- ✓ PostgreSQL database server
- ✓ Wiki.js system user and directories
- ✓ Nginx reverse proxy (if domain is set)
- ✓ Automatic SSL certificates (if enableSSL = true)
- ✓ Database backups (if backupPath is set)
- ✓ Firewall rules (if openFirewall = true)


================================================================================
UNDERSTANDING WIKI.JS STRUCTURE
================================================================================

Data Directory (dataDir):
-------------------------
Contains:
- Wiki.js configuration files
- Page cache
- Temporary files
- data/uploads/ (or symlink if using custom uploadsPath)

Default: /var/lib/wiki-js


Uploads Path (uploadsPath):
---------------------------
Stores:
- Uploaded images
- File attachments
- User avatars

By default, stored under dataDir/data/uploads/
Set uploadsPath to use a different location (e.g., larger storage drive)


Database:
---------
- PostgreSQL database named "wiki-js"
- Stores page content, users, settings
- Located in PostgreSQL's data directory
- Backed up automatically if backupPath is set


Backups:
--------
- Only backs up the PostgreSQL database
- Uploads are NOT backed up automatically
- Consider separate backup solution for uploadsPath
- Backup files are compressed with zstd


================================================================================
COMMON USE CASES
================================================================================

Personal wiki (localhost only):
--------------------------------
services.wikijs-custom = {
  enable = true;
  # All defaults work fine for personal use
};


Team wiki with network access:
-------------------------------
services.wikijs-custom = {
  enable = true;
  bindIP = "0.0.0.0";
  backupPath = "/backup/wiki-js";
  backupSchedule = "daily";
};


Production wiki with domain and SSL:
-------------------------------------
services.wikijs-custom = {
  enable = true;
  domain = "wiki.example.com";
  enableSSL = true;
  dataDir = "/data/wiki-js";
  uploadsPath = "/mnt/storage/wiki-uploads";
  backupPath = "/backup/wiki-js";
  backupSchedule = "02:00";
};


================================================================================
STORAGE OPTIONS IN WIKI.JS
================================================================================

After setup, you can configure different storage backends in the Wiki.js admin:

Local Storage (default):
  - Files stored in dataDir/data/uploads
  - Good for: Small wikis, single server

Git Storage:
  - Store pages in Git repository
  - Good for: Version control, collaboration

Cloud Storage:
  - AWS S3, Azure Blob, Google Cloud Storage
  - Good for: Scalability, redundancy

Database Storage:
  - Store everything in PostgreSQL
  - Good for: Simplicity, atomic backups


================================================================================
BACKUP STRATEGY
================================================================================

What gets backed up automatically:
  ✓ PostgreSQL database (if backupPath is set)
  ✓ Page content
  ✓ User accounts
  ✓ Configuration

What you should backup separately:
  ✗ Uploaded files (if using local storage)
  ✗ Custom themes/templates
  ✗ SSL certificates

Recommended backup approach:
  1. Enable automatic database backups (backupPath)
  2. Set up rsync/restic for uploadsPath
  3. Store backups off-site or on different drive


Restore from backup:
  1. Stop Wiki.js: sudo systemctl stop wiki-js
  2. Restore database: sudo -u postgres psql wiki-js < backup.sql
  3. Restore uploads: rsync -av backup/ /path/to/uploads/
  4. Start Wiki.js: sudo systemctl start wiki-js


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status wiki-js

View logs:
  sudo journalctl -u wiki-js -f

Check database connection:
  sudo -u wiki-js psql -d wiki-js -c "\dt"

Verify uploads symlink (if using custom path):
  ls -la /var/lib/wiki-js/data/uploads

Check backup location:
  ls -lh /backup/wiki-js/

Reset to defaults (WARNING: deletes all content):
  sudo systemctl stop wiki-js
  sudo -u postgres dropdb wiki-js
  sudo -u postgres createdb -O wiki-js wiki-js
  sudo rm -rf /var/lib/wiki-js/*
  sudo systemctl start wiki-js

Cannot access web interface:
  1. Check if service is running: systemctl status wiki-js
  2. Check firewall: sudo ss -tulpn | grep 3001
  3. Check logs: journalctl -u wiki-js -n 50


Database connection errors:
  1. Ensure PostgreSQL is running: systemctl status postgresql
  2. Check database exists: sudo -u postgres psql -l | grep wiki-js
  3. Check user permissions: sudo -u postgres psql wiki-js -c "\du"


Out of disk space:
  1. Check disk usage: df -h
  2. Clean old backups: find /backup/wiki-js -mtime +30 -delete
  3. Consider moving uploads: set uploadsPath to larger drive


================================================================================
SECURITY BEST PRACTICES
================================================================================

✓ Use HTTPS in production (set enableSSL = true)
✓ Keep Wiki.js updated (rebuild NixOS regularly)
✓ Use strong admin password
✓ Enable 2FA for administrator accounts
✓ Restrict bindIP to localhost if using reverse proxy
✓ Regular backups (enable backupPath)
✓ Monitor logs for suspicious activity
✓ Use authentication providers (LDAP/OAuth) for team wikis


================================================================================
UPGRADING WIKI.JS
================================================================================

Wiki.js is automatically updated when you rebuild NixOS:

  sudo nixos-rebuild switch

The service will restart automatically with the new version.
Your data and configuration are preserved during upgrades.

Note: Major version upgrades may require database migrations.
Always backup before upgrading!


================================================================================
INTEGRATIONS
================================================================================

Wiki.js supports many integrations via the admin interface:

Authentication:
  - Local accounts
  - LDAP / Active Directory
  - OAuth2 (Google, GitHub, etc.)
  - SAML

Search:
  - PostgreSQL full-text search (default)
  - Elasticsearch
  - Algolia
  - Azure Search

Analytics:
  - Google Analytics
  - Matomo
  - Fathom

*/
