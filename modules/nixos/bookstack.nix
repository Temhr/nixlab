{ config, lib, pkgs, ... }:

let
  cfg = config.services.bookstack-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.bookstack-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "BookStack service";

      # OPTIONAL: Port to listen on (default: 6875)
      port = lib.mkOption {
        type = lib.types.port;
        default = 6875;
        description = "Port for BookStack to listen on";
      };

      # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
      # Use "0.0.0.0" for access from other devices
      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
      };

      # REQUIRED: Your domain name for BookStack
      domain = lib.mkOption {
        type = lib.types.str;
        example = "wiki.example.com";
        description = "Domain name for BookStack (required)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt";
      };

      # OPTIONAL: Where to store BookStack data (default: /var/lib/bookstack)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/bookstack";
        example = "/data/bookstack";
        description = "Directory for BookStack data";
      };

      # OPTIONAL: Location of encryption key file (default: /var/lib/bookstack-appkey)
      # You must generate this manually before first run
      appKeyFile = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/bookstack-appkey";
        description = "Path to file containing the app key";
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
      # Create data directory owned by bookstack user
      "d ${cfg.dataDir} 0770 bookstack bookstack -"
      # Create app key file (you must populate it manually)
      "f ${cfg.appKeyFile} 0660 bookstack bookstack -"
    ];

    users.users.temhr.extraGroups = [ "bookstack" ];

    # ----------------------------------------------------------------------------
    # DATABASE SETUP - BookStack requires MySQL/MariaDB
    # ----------------------------------------------------------------------------
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      # Create the 'bookstack' database automatically
      ensureDatabases = [ "bookstack" ];
      # Create 'bookstack' user with full permissions on the database
      ensureUsers = [{
        name = "bookstack";
        ensurePermissions = {
          "bookstack.*" = "ALL PRIVILEGES";
        };
      }];
    };

    # ----------------------------------------------------------------------------
    # BOOKSTACK SERVICE - Configure the built-in NixOS BookStack module
    # ----------------------------------------------------------------------------
    services.bookstack = {
      enable = true;
      # Domain where BookStack will be accessible
      hostname = cfg.domain;

      # BookStack application settings
      settings = {
        # Path to file containing encryption key (APP_KEY)
        APP_KEY_FILE = cfg.appKeyFile;
      };

      # Nginx web server configuration (BookStack requires a reverse proxy)
      nginx = {
        # Enable automatic SSL certificate from Let's Encrypt
        enableACME = cfg.enableSSL;
        # Force all traffic to HTTPS
        forceSSL = cfg.enableSSL;
        # Configure listening address and port
        listen = [
          { addr = cfg.bindIP; port = cfg.port; ssl = false; }
        ];
      };
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      # Always open the configured port
      [ cfg.port ]
      # Also open HTTP (80) and HTTPS (443) if SSL is enabled
      ++ lib.optionals cfg.enableSSL [ 80 443 ]
    );
  };
}

/*
================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration (only required options):
----------------------------------------------
services.bookstack-custom = {
  enable = true;
  domain = "wiki.example.com";  # REQUIRED
};


Full configuration (all options):
----------------------------------
services.bookstack-custom = {
  enable = true;                  # REQUIRED: Turn on the service
  domain = "wiki.example.com";    # REQUIRED: Your domain name
  port = 3002;                    # OPTIONAL: Default is 3002
  bindIP = "0.0.0.0";            # OPTIONAL: Default is 0.0.0.0 (all interfaces)
  enableSSL = true;               # OPTIONAL: Default is false
  dataDir = "/data/bookstack";    # OPTIONAL: Default is /var/lib/bookstack
  appKeyFile = "/var/lib/bookstack-appkey";  # OPTIONAL: Default shown
  openFirewall = true;            # OPTIONAL: Default is true
};


================================================================================
FIRST-TIME SETUP INSTRUCTIONS
================================================================================

Step 1: Generate the encryption key
------------------------------------
The appKeyFile MUST be created manually before starting BookStack:

  echo "base64:$(openssl rand -base64 32)" | sudo tee /var/lib/bookstack-appkey
  sudo chown bookstack:bookstack /var/lib/bookstack-appkey
  sudo chmod 600 /var/lib/bookstack-appkey


Step 2: Apply your NixOS configuration
---------------------------------------
  sudo nixos-rebuild switch


Step 3: Access BookStack
-------------------------
Visit: http://your-domain:3002 (or https:// if enableSSL = true)


Step 4: Login with default credentials
---------------------------------------
  Email: admin@admin.com
  Password: password

  ⚠️  CHANGE THESE IMMEDIATELY AFTER FIRST LOGIN!


================================================================================
WHAT GETS INSTALLED
================================================================================

This module automatically sets up:
- ✓ BookStack application
- ✓ MariaDB database server
- ✓ Nginx reverse proxy
- ✓ Automatic SSL certificates (if enableSSL = true)
- ✓ Firewall rules (if openFirewall = true)
- ✓ System user and directories


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status bookstack

View logs:
  sudo journalctl -u bookstack -f

Check if port is open:
  sudo ss -tulpn | grep 3002

Verify app key file exists:
  sudo cat /var/lib/bookstack-appkey

*/
