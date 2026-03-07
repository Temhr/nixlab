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
      enable = lib.mkEnableOption "BookStack wiki service";

      # OPTIONAL: Port for the BookStack app container (default: 6875)
      port = lib.mkOption {
        type = lib.types.port;
        default = 6875;
        description = "Port for BookStack to listen on";
      };

      # OPTIONAL: IP to bind to (default: 0.0.0.0 = all interfaces, good for LAN)
      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "IP address to bind to (use 0.0.0.0 for LAN access)";
      };

      # OPTIONAL: Domain or IP used in the APP_URL
      # Can be a domain like "bookstack.home", a .local mDNS name, or an IP like "192.168.1.x"
      appURL = lib.mkOption {
        type = lib.types.str;
        default = "http://localhost:6875";
        example = "http://192.168.0.50:6875";
        description = "Full URL BookStack will use for links and assets (no trailing slash)";
      };

      # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "bookstack.home";
        description = "Domain name for nginx reverse proxy (optional, no domain registration required)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      # Only works if domain is set and publicly resolvable
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires a publicly resolvable domain)";
      };

      # OPTIONAL: Where to store persistent BookStack data (default: /var/lib/bookstack)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/bookstack";
        example = "/data/bookstack";
        description = "Directory for BookStack and database persistent storage";
      };

      # REQUIRED (sops): Path to sops-decrypted env file for the MariaDB root password
      # File must contain:  MYSQL_ROOT_PASSWORD=yourpassword
      # Set via: sops.secrets.bookstack_db_root.path
      dbRootPasswordFile = lib.mkOption {
        type = lib.types.path;
        example = "/run/secrets/bookstack_db_root";
        description = ''
          Path to a sops-decrypted env file containing the MariaDB root password.
          The file must contain a single line: MYSQL_ROOT_PASSWORD=yourpassword
          Provide this via sops-nix: config.sops.secrets.bookstack_db_root.path
        '';
      };

      # REQUIRED (sops): Path to sops-decrypted env file for the BookStack DB user password
      # File must contain both:
      #   MYSQL_PASSWORD=yourpassword   (for the MariaDB container)
      #   DB_PASS=yourpassword          (for the BookStack container)
      # Set via: sops.secrets.bookstack_db_pass.path
      dbPasswordFile = lib.mkOption {
        type = lib.types.path;
        example = "/run/secrets/bookstack_db_pass";
        description = ''
          Path to a sops-decrypted env file containing the BookStack DB user password.
          The file must contain:
            MYSQL_PASSWORD=yourpassword
            DB_PASS=yourpassword
          Provide this via sops-nix: config.sops.secrets.bookstack_db_pass.path
        '';
      };

      # OPTIONAL: Auto-open firewall ports (default: true)
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports for LAN access";
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # ----------------------------------------------------------------------------
    # DIRECTORY SETUP - Create persistent data directories for containers
    # ----------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}              0750 root root -"
      "d ${cfg.dataDir}/bookstack    0750 root root -"
      "d ${cfg.dataDir}/db           0750 root root -"
    ];

    # ----------------------------------------------------------------------------
    # CONTAINER BACKEND - Enable Podman for rootless-friendly OCI containers
    # ----------------------------------------------------------------------------
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
    };

    # ----------------------------------------------------------------------------
    # DATABASE CONTAINER - MariaDB backend for BookStack
    # Passwords are injected via environmentFiles — never stored in the Nix store
    # ----------------------------------------------------------------------------
    virtualisation.oci-containers.containers.bookstack-db = {
      image = "lscr.io/linuxserver/mariadb:latest";

      environment = {
        PUID           = "1000";
        PGID           = "1000";
        MYSQL_DATABASE = "bookstack";
        MYSQL_USER     = "bookstack";
        # Passwords are NOT set here — injected at runtime via environmentFiles
      };

      # sops-nix decrypts these to /run/secrets/* at boot (root-readable only)
      # dbRootPasswordFile contains: MYSQL_ROOT_PASSWORD=...
      # dbPasswordFile contains:     MYSQL_PASSWORD=...
      environmentFiles = [
        cfg.dbRootPasswordFile
        cfg.dbPasswordFile
      ];

      volumes = [
        "${cfg.dataDir}/db:/config"
      ];

      extraOptions = [ "--network=host" ];
    };

    # ----------------------------------------------------------------------------
    # BOOKSTACK CONTAINER - The main application
    # Password injected via environmentFiles — never stored in the Nix store
    # ----------------------------------------------------------------------------
    virtualisation.oci-containers.containers.bookstack = {
      image = "lscr.io/linuxserver/bookstack:latest";

      environment = {
        PUID        = "1000";
        PGID        = "1000";
        APP_URL     = cfg.appURL;
        DB_HOST     = "127.0.0.1";
        DB_PORT     = "3306";
        DB_USER     = "bookstack";
        DB_DATABASE = "bookstack";
        # DB_PASS is NOT set here — injected at runtime via environmentFiles
      };

      # dbPasswordFile must also contain: DB_PASS=...
      environmentFiles = [
        cfg.dbPasswordFile
      ];

      volumes = [
        "${cfg.dataDir}/bookstack:/config"
      ];

      ports = lib.optionals (cfg.domain == null) [
        "${cfg.bindIP}:${toString cfg.port}:80"
      ] ++ lib.optionals (cfg.domain != null) [
        "127.0.0.1:${toString cfg.port}:80"
      ];

      # Ensures DB container starts first
      dependsOn = [ "bookstack-db" ];

      extraOptions = [ "--network=host" ];
    };

    # ----------------------------------------------------------------------------
    # NGINX REVERSE PROXY - Only configured if domain is set
    # ----------------------------------------------------------------------------
    services.nginx.enable = lib.mkIf (cfg.domain != null) true;

    services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
      ${cfg.domain} = {
        forceSSL   = cfg.enableSSL;
        enableACME = cfg.enableSSL;

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
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
    # FIREWALL - Open necessary ports for LAN access
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      # Expose BookStack port directly if not behind a reverse proxy
      lib.optionals (cfg.domain == null) [ cfg.port ]
      # Expose HTTP/HTTPS if using reverse proxy
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );
  };
}

/*
================================================================================
USAGE EXAMPLES
================================================================================

Minimal (LAN access via IP):
------------------------------
services.bookstack-custom = {
  enable             = true;
  appURL             = "http://192.168.1.50:6875";
  dbRootPasswordFile = config.sops.secrets.bookstack_db_root.path;
  dbPasswordFile     = config.sops.secrets.bookstack_db_pass.path;
};
# Access at: http://192.168.1.50:6875
# Default login: admin@admin.com / password  !! change immediately !!


With mDNS .local hostname (no domain registration needed):
-----------------------------------------------------------
services.avahi = {
  enable   = true;
  nssmdns4 = true;
  publish  = { enable = true; addresses = true; };
};
networking.hostName = "bookstack";

services.bookstack-custom = {
  enable             = true;
  appURL             = "http://bookstack.local";
  dbRootPasswordFile = config.sops.secrets.bookstack_db_root.path;
  dbPasswordFile     = config.sops.secrets.bookstack_db_pass.path;
};
# Access at: http://bookstack.local
# Works on Linux, macOS, iOS automatically. Windows needs Bonjour.


Full configuration with nginx reverse proxy:
--------------------------------------------
services.bookstack-custom = {
  enable             = true;
  port               = 6875;
  bindIP             = "0.0.0.0";
  appURL             = "http://bookstack.home";
  dataDir            = "/data/bookstack";
  domain             = "bookstack.home";  # Resolve via Pi-hole or router DNS
  enableSSL          = false;             # No Let's Encrypt for LAN-only domains
  dbRootPasswordFile = config.sops.secrets.bookstack_db_root.path;
  dbPasswordFile     = config.sops.secrets.bookstack_db_pass.path;
  openFirewall       = true;
};


================================================================================
FIRST-RUN NOTES
================================================================================

Default admin credentials:
  Email:    admin@admin.com
  Password: password
  !! Change these immediately after first login !!

The database container must be healthy before BookStack starts.
On first boot this may take 30-60 seconds. If BookStack shows a DB error,
wait a moment and refresh — MariaDB is still initialising.


================================================================================
MANAGEMENT
================================================================================

Check service status:
  sudo systemctl status podman-bookstack
  sudo systemctl status podman-bookstack-db

View logs:
  sudo journalctl -u podman-bookstack -f
  sudo journalctl -u podman-bookstack-db -f

Restart services:
  sudo systemctl restart podman-bookstack-db
  sudo systemctl restart podman-bookstack

Pull latest images and restart:
  sudo podman pull lscr.io/linuxserver/bookstack:latest
  sudo podman pull lscr.io/linuxserver/mariadb:latest
  sudo systemctl restart podman-bookstack-db podman-bookstack

Rotate secrets:
  nix-shell -p sops --run "sops secrets/bookstack.yaml"  # edit & save
  sudo nixos-rebuild switch                               # re-decrypts at activation


================================================================================
TROUBLESHOOTING
================================================================================

BookStack shows "Could not connect to database":
  - DB container may still be starting. Wait 30s and refresh.
  - Check: sudo journalctl -u podman-bookstack-db -f

Secrets not decrypting / permission denied on env file:
  - Confirm your age key exists at the path in sops.age.keyFile
  - Check: sudo systemctl status sops-nix
  - Verify /run/secrets/bookstack_db_pass exists after boot

APP_URL mismatch (assets not loading / broken layout):
  - appURL must exactly match the address you type in the browser.
  - No trailing slash on appURL.

Can't reach from LAN:
  - Ensure bindIP = "0.0.0.0" (not 127.0.0.1).
  - Ensure openFirewall = true.

.local hostname not resolving on Windows:
  - Install Apple Bonjour (comes with iTunes) or enable mDNS in Windows settings.

*/
