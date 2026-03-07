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

      # OPTIONAL: Port BookStack listens on from the host (default: 6875)
      # This is the port you access in the browser, e.g. http://192.168.1.x:6875
      port = lib.mkOption {
        type    = lib.types.port;
        default = 6875;
        description = "Host port to expose BookStack on";
      };

      # OPTIONAL: IP to bind to (default: 0.0.0.0 = all interfaces)
      # Use 0.0.0.0 for LAN access. Use 127.0.0.1 to restrict to localhost only.
      bindIP = lib.mkOption {
        type    = lib.types.str;
        default = "0.0.0.0";
        description = "IP address to bind to (use 0.0.0.0 for LAN access)";
      };

      # REQUIRED: The full URL used to access BookStack in the browser.
      # BookStack embeds this into all internal links and asset URLs.
      # Must exactly match what you type in the browser — same IP/hostname and port.
      # No trailing slash. Examples:
      #   http://192.168.1.50:6875
      #   http://bookstack.local        (with Avahi mDNS)
      #   http://bookstack.home         (with Pi-hole or router DNS)
      appURL = lib.mkOption {
        type    = lib.types.str;
        default = "http://localhost:6875";
        example = "http://192.168.1.50:6875";
        description = "Full URL BookStack is accessed at (no trailing slash). Must match browser address exactly.";
      };

      # OPTIONAL: Domain name for an nginx reverse proxy (default: null = no proxy)
      # When set, nginx proxies requests from this domain to BookStack.
      # No domain registrar needed for LAN — use a Pi-hole, router DNS, or .local mDNS name.
      # When using a domain, set appURL to match, e.g. appURL = "http://bookstack.home"
      domain = lib.mkOption {
        type    = lib.types.nullOr lib.types.str;
        default = null;
        example = "bookstack.home";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable HTTPS via Let's Encrypt (default: false)
      # Only works with publicly resolvable domains. Do not enable for LAN-only domains.
      enableSSL = lib.mkOption {
        type    = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires a publicly resolvable domain)";
      };

      # OPTIONAL: Directory for all persistent data — BookStack files and the database.
      # If this is on a separate drive, also set dataMountUnit below.
      dataDir = lib.mkOption {
        type    = lib.types.path;
        default = "/var/lib/bookstack";
        example = "/data/bookstack";
        description = "Directory for BookStack and MariaDB persistent storage";
      };

      # OPTIONAL: systemd mount unit for the drive that hosts dataDir (default: null)
      # Set this if dataDir lives on a separate drive so systemd waits for the
      # drive to mount before attempting to start the containers.
      # The unit name is derived from the mount path:
      #   replace all slashes with dashes, then drop the leading dash.
      # Examples:
      #   /data           ->  data.mount
      #   /mnt/storage    ->  mnt-storage.mount
      #   /mnt/data/wiki  ->  mnt-data-wiki.mount
      dataMountUnit = lib.mkOption {
        type    = lib.types.nullOr lib.types.str;
        default = null;
        example = "data.mount";
        description = "systemd mount unit for the drive hosting dataDir. Containers wait for it before starting.";
      };

      # REQUIRED: sops-nix path to the decrypted MariaDB root password.
      # sops-nix decrypts secrets to bare values (just the password, no KEY= prefix).
      # The module handles wrapping it correctly — you just point it at the secret path.
      # In your secrets YAML file this key should be named: MYSQL_ROOT_PASSWORD
      # In configuration.nix:  dbRootPasswordFile = config.sops.secrets.MYSQL_ROOT_PASSWORD.path;
      dbRootPasswordFile = lib.mkOption {
        type    = lib.types.path;
        example = "/run/secrets/MYSQL_ROOT_PASSWORD";
        description = ''
          Path to sops-decrypted MariaDB root password (bare value, no KEY= prefix).
          Declare in configuration.nix:
            sops.secrets.MYSQL_ROOT_PASSWORD.sopsFile = ./secrets/bookstack.yaml;
          Then pass: config.sops.secrets.MYSQL_ROOT_PASSWORD.path
        '';
      };

      # REQUIRED: sops-nix path to the decrypted BookStack database user password.
      # Used for both MariaDB (MYSQL_PASSWORD) and BookStack (DB_PASSWORD).
      # In your secrets YAML file this key should be named: MYSQL_PASSWORD
      # In configuration.nix:  dbPasswordFile = config.sops.secrets.MYSQL_PASSWORD.path;
      dbPasswordFile = lib.mkOption {
        type    = lib.types.path;
        example = "/run/secrets/MYSQL_PASSWORD";
        description = ''
          Path to sops-decrypted BookStack DB user password (bare value, no KEY= prefix).
          Declare in configuration.nix:
            sops.secrets.MYSQL_PASSWORD.sopsFile = ./secrets/bookstack.yaml;
          Then pass: config.sops.secrets.MYSQL_PASSWORD.path
        '';
      };

      # REQUIRED: sops-nix path to the decrypted BookStack APP_KEY.
      # This is a Laravel encryption key used to secure sessions and encrypted data.
      # Generate it once with:
      #   sudo podman run -it --rm --entrypoint /bin/bash \
      #     lscr.io/linuxserver/bookstack:latest appkey
      # Store the output (base64:...) as the APP_KEY value in your secrets YAML.
      # WARNING: Never change this after first setup — doing so invalidates all sessions.
      # In configuration.nix:  appKeyFile = config.sops.secrets.APP_KEY.path;
      appKeyFile = lib.mkOption {
        type    = lib.types.path;
        example = "/run/secrets/APP_KEY";
        description = ''
          Path to sops-decrypted BookStack APP_KEY (bare value, no KEY= prefix).
          Declare in configuration.nix:
            sops.secrets.APP_KEY.sopsFile = ./secrets/bookstack.yaml;
          Then pass: config.sops.secrets.APP_KEY.path
        '';
      };

      # OPTIONAL: Open firewall ports automatically (default: true)
      # Opens the BookStack port when accessed directly, or ports 80/443 when
      # using the nginx reverse proxy. Disable if you manage firewall rules manually.
      openFirewall = lib.mkOption {
        type    = lib.types.bool;
        default = true;
        description = "Automatically open firewall ports for BookStack";
      };

    };
  };

  # ============================================================================
  # CONFIG - What is created when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # --------------------------------------------------------------------------
    # DIRECTORY INIT SERVICE
    # A dedicated oneshot service creates the data directories before the
    # containers start. This is used instead of systemd.tmpfiles so that we can
    # correctly wait for a separate drive mount (dataMountUnit) if needed.
    # --------------------------------------------------------------------------
    systemd.services.bookstack-init-dirs = {
      description   = "Create BookStack data directories";
      wantedBy      = [ "multi-user.target" ];
      before        = [ "podman-bookstack-db.service" "podman-bookstack.service" ];
      after         = [ "local-fs.target" ]
                      ++ lib.optionals (cfg.dataMountUnit != null) [ cfg.dataMountUnit ];
      requires      = lib.optionals (cfg.dataMountUnit != null) [ cfg.dataMountUnit ];
      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p ${cfg.dataDir}/bookstack
        mkdir -p ${cfg.dataDir}/db
        chmod 750 ${cfg.dataDir} ${cfg.dataDir}/bookstack ${cfg.dataDir}/db
      '';
    };

    # --------------------------------------------------------------------------
    # CONTAINER BACKEND - Podman
    # --------------------------------------------------------------------------
    virtualisation.podman = {
      enable       = true;
      dockerCompat = true;
    };

    # --------------------------------------------------------------------------
    # DATABASE CONTAINER - MariaDB (linuxserver image)
    # Uses --network=host so MariaDB binds directly to the host network stack,
    # making it reachable from the BookStack container via host.containers.internal.
    #
    # sops-nix decrypts secrets to bare values (just the password string).
    # The preStart script wraps them into KEY=value format that environmentFiles
    # requires, writing to /run/bookstack-db.env (in-memory, wiped on reboot).
    # --------------------------------------------------------------------------
    virtualisation.oci-containers.containers.bookstack-db = {
      image = "lscr.io/linuxserver/mariadb:latest";

      environment = {
        PUID           = "1000";
        PGID           = "1000";
        MYSQL_DATABASE = "bookstack";
        MYSQL_USER     = "bookstack";
        # Passwords injected via /run/bookstack-db.env — not hardcoded here
      };

      environmentFiles = [ /run/bookstack-db.env ];

      volumes = [ "${cfg.dataDir}/db:/config" ];

      extraOptions = [ "--network=host" ];
    };

    systemd.services.podman-bookstack-db = {
      after    = [ "bookstack-init-dirs.service" ]
                 ++ lib.optionals (cfg.dataMountUnit != null) [ cfg.dataMountUnit ];
      requires = [ "bookstack-init-dirs.service" ];
      # Build the env file from bare sops secret values before the container starts
      preStart = lib.mkBefore ''
        echo "MYSQL_ROOT_PASSWORD=$(cat ${cfg.dbRootPasswordFile})" >  /run/bookstack-db.env
        echo "MYSQL_PASSWORD=$(cat ${cfg.dbPasswordFile})"          >> /run/bookstack-db.env
        chmod 600 /run/bookstack-db.env
      '';
    };

    # --------------------------------------------------------------------------
    # BOOKSTACK CONTAINER - Application (linuxserver image)
    # Uses bridge networking (no --network=host) so port mapping works correctly.
    # Reaches MariaDB via host.containers.internal which Podman automatically
    # resolves to the host from inside any bridge-networked container.
    #
    # BookStack reads all config from /config/www/.env inside the container
    # (mapped to ${dataDir}/bookstack/www/.env on the host). The container's
    # init script would overwrite this with a default template on every start,
    # so the preStart script writes the correct values before the container
    # starts, ensuring the init script sees the file and skips the template copy.
    # --------------------------------------------------------------------------
    virtualisation.oci-containers.containers.bookstack = {
      image = "lscr.io/linuxserver/bookstack:latest";

      environment = {
        PUID        = "1000";
        PGID        = "1000";
        # These env vars are used by the container's DB connectivity health check.
        # The actual BookStack config is written to .env by the preStart script.
        APP_URL     = cfg.appURL;
        DB_HOST     = "host.containers.internal";
        DB_PORT     = "3306";
        DB_USER     = "bookstack";
        DB_DATABASE = "bookstack";
      };

      # /run/bookstack-app.env is generated by the preStart script below
      environmentFiles = [ /run/bookstack-app.env ];

      volumes = [ "${cfg.dataDir}/bookstack:/config" ];

      # Bridge networking — port mapping works, BookStack reaches DB via host gateway
      ports = lib.optionals (cfg.domain == null) [
        "${cfg.bindIP}:${toString cfg.port}:80"
      ] ++ lib.optionals (cfg.domain != null) [
        "127.0.0.1:${toString cfg.port}:80"
      ];

      dependsOn = [ "bookstack-db" ];
    };

    systemd.services.podman-bookstack = {
      after    = [ "bookstack-init-dirs.service" ]
                 ++ lib.optionals (cfg.dataMountUnit != null) [ cfg.dataMountUnit ];
      requires = [ "bookstack-init-dirs.service" ];
      preStart = lib.mkBefore ''
        # Read bare secret values
        DB_PASS_VAL=$(cat ${cfg.dbPasswordFile})
        APP_KEY_VAL=$(cat ${cfg.appKeyFile})

        # Write container env file (DB_PASS and APP_KEY in KEY=value format)
        echo "DB_PASS=$DB_PASS_VAL" >  /run/bookstack-app.env
        echo "APP_KEY=$APP_KEY_VAL" >> /run/bookstack-app.env
        chmod 600 /run/bookstack-app.env

        # Write the BookStack .env config file before the container starts.
        # BookStack reads ALL configuration from this file — env vars alone are
        # not sufficient. The container init script skips copying the default
        # template if this file already exists, so we write it here on every
        # start to ensure it always reflects current secrets and settings.
        mkdir -p ${cfg.dataDir}/bookstack/www
        cat > ${cfg.dataDir}/bookstack/www/.env <<ENVEOF
APP_KEY=$APP_KEY_VAL
APP_URL=${cfg.appURL}
DB_HOST=host.containers.internal
DB_PORT=3306
DB_DATABASE=bookstack
DB_USERNAME=bookstack
DB_PASSWORD=$DB_PASS_VAL
STORAGE_TYPE=local
MAIL_DRIVER=smtp
MAIL_FROM_NAME="BookStack"
MAIL_FROM=bookstack@example.com
MAIL_HOST=localhost
MAIL_PORT=587
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
ENVEOF
        chmod 640 ${cfg.dataDir}/bookstack/www/.env
      '';
    };

    # --------------------------------------------------------------------------
    # NGINX REVERSE PROXY - Only configured when domain is set
    # --------------------------------------------------------------------------
    services.nginx.enable = lib.mkIf (cfg.domain != null) true;

    services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
      ${cfg.domain} = {
        forceSSL   = cfg.enableSSL;
        enableACME = cfg.enableSSL;
        locations."/" = {
          proxyPass      = "http://127.0.0.1:${toString cfg.port}";
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

    # --------------------------------------------------------------------------
    # FIREWALL
    # Opens the BookStack port for direct access, or 80/443 when using nginx.
    # Also opens port 3306 to the Podman bridge network (10.88.0.0/16) so the
    # BookStack container can reach MariaDB on the host via host.containers.internal.
    # --------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      lib.optionals (cfg.domain == null) [ cfg.port ]
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );

    # Allow the BookStack container (Podman bridge 10.88.0.0/16) to reach MariaDB
    # on the host. Uses nftables extraInputRules for compatibility with nftables-based
    # NixOS firewall configs (the podman+ wildcard does not work with nftables).
    networking.firewall.extraInputRules = ''
      ip saddr 10.88.0.0/16 tcp dport 3306 accept
    '';

  };
}

/*
================================================================================
SECRETS FILE SETUP
================================================================================

Your secrets/bookstack.yaml should contain these four keys.
The values are plain strings — sops encrypts the file, not individual values.

  MYSQL_ROOT_PASSWORD: your_mariadb_root_password
  MYSQL_PASSWORD: your_bookstack_db_password
  APP_KEY: base64:your_generated_app_key_here=

Generate APP_KEY once with:
  sudo podman run -it --rm --entrypoint /bin/bash \
    lscr.io/linuxserver/bookstack:latest appkey

Encrypt the file:
  sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
    nix-shell -p sops --run "sops secrets/bookstack.yaml"

Edit it later with the same command.

WARNING: Never change APP_KEY after first setup — it invalidates all user sessions.


================================================================================
CONFIGURATION.NIX WIRING
================================================================================

Declare secrets (elegant shorthand using lib.genAttrs):

  sops.secrets = lib.genAttrs
    [ "MYSQL_ROOT_PASSWORD" "MYSQL_PASSWORD" "APP_KEY" ]
    (_: { sopsFile = self + "/secrets/bookstack.yaml"; });

Wire the module:

  services.bookstack-custom = {
    enable             = true;
    appURL             = "http://192.168.1.50:6875";   # your LAN IP
    dbRootPasswordFile = config.sops.secrets.MYSQL_ROOT_PASSWORD.path;
    dbPasswordFile     = config.sops.secrets.MYSQL_PASSWORD.path;
    appKeyFile         = config.sops.secrets.APP_KEY.path;
  };

With dataDir on a separate drive:

  services.bookstack-custom = {
    enable             = true;
    appURL             = "http://192.168.1.50:6875";
    dataDir            = "/data/bookstack";
    dataMountUnit      = "data.mount";   # /data -> data.mount
    dbRootPasswordFile = config.sops.secrets.MYSQL_ROOT_PASSWORD.path;
    dbPasswordFile     = config.sops.secrets.MYSQL_PASSWORD.path;
    appKeyFile         = config.sops.secrets.APP_KEY.path;
  };

  # dataMountUnit name = mount path with slashes -> dashes, drop leading dash
  # /data          ->  data.mount
  # /mnt/storage   ->  mnt-storage.mount

With mDNS .local hostname (no domain registrar needed):

  services.avahi = {
    enable   = true;
    nssmdns4 = true;
    publish  = { enable = true; addresses = true; };
  };
  networking.hostName = "bookstack";

  services.bookstack-custom = {
    enable             = true;
    appURL             = "http://bookstack.local";
    dbRootPasswordFile = config.sops.secrets.MYSQL_ROOT_PASSWORD.path;
    dbPasswordFile     = config.sops.secrets.MYSQL_PASSWORD.path;
    appKeyFile         = config.sops.secrets.APP_KEY.path;
  };
  # Works on Linux, macOS, iOS. Windows needs Bonjour (comes with iTunes).

With nginx reverse proxy (LAN domain via Pi-hole or router DNS):

  services.bookstack-custom = {
    enable             = true;
    appURL             = "http://bookstack.home";
    domain             = "bookstack.home";
    enableSSL          = false;   # only enable for publicly resolvable domains
    dataDir            = "/data/bookstack";
    dataMountUnit      = "data.mount";
    dbRootPasswordFile = config.sops.secrets.MYSQL_ROOT_PASSWORD.path;
    dbPasswordFile     = config.sops.secrets.MYSQL_PASSWORD.path;
    appKeyFile         = config.sops.secrets.APP_KEY.path;
  };


================================================================================
FIRST RUN
================================================================================

Default login after first boot:
  URL:      http://your-ip:6875
  Email:    admin@admin.com
  Password: password
  !! Change both immediately after logging in !!

The database initialises on first boot and may take 30-60 seconds.
If you see a database error on first visit, wait and refresh.

If you see a 500 error on first boot, the database may have leftover tables
from a previous failed attempt. Fix with:
  sudo systemctl stop podman-bookstack podman-bookstack-db
  sudo rm -rf /your/dataDir/db/*
  sudo systemctl start podman-bookstack-db
  # wait ~30 seconds, then:
  sudo systemctl start podman-bookstack


================================================================================
MANAGEMENT
================================================================================

Status:
  sudo systemctl status podman-bookstack
  sudo systemctl status podman-bookstack-db

Logs:
  sudo journalctl -u podman-bookstack -f
  sudo journalctl -u podman-bookstack-db -f

Restart:
  sudo systemctl restart podman-bookstack-db
  sudo systemctl restart podman-bookstack

Update to latest images:
  sudo podman pull lscr.io/linuxserver/bookstack:latest
  sudo podman pull lscr.io/linuxserver/mariadb:latest
  sudo systemctl restart podman-bookstack-db podman-bookstack

Rotate secrets (change passwords):
  sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
    nix-shell -p sops --run "sops secrets/bookstack.yaml"
  sudo nixos-rebuild switch
  sudo systemctl restart podman-bookstack-db podman-bookstack


================================================================================
TROUBLESHOOTING
================================================================================

"Could not connect to database" / 500 on first load:
  - DB may still be initialising. Wait 30s and refresh.
  - Check: sudo journalctl -u podman-bookstack-db -f

Broken layout / missing assets:
  - appURL must exactly match what you type in the browser, including port.
  - No trailing slash on appURL.

Can't reach from LAN:
  - Ensure bindIP = "0.0.0.0".
  - Ensure openFirewall = true.
  - Check: sudo ss -tlnp | grep 6875

Secrets not available / permission denied:
  - Check age key exists: ls -la /var/lib/sops-nix/key.txt
  - Check: sudo systemctl status sops-nix

nftables build error with firewall.interfaces."podman+":
  - The podman+ wildcard does not work with nftables.
  - This module uses extraInputRules instead, which is nftables-compatible.

*/
