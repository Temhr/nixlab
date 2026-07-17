{self, ...}: {
  flake.nixosModules.servc--ntfy-nixlab = {
    config,
    lib,
    pkgs,
    nixlabLib,
    ...
  }: let
    cfg = config.services.ntfy-nixlab;
  in {
    imports = [
      self.nixosModules.systm--ports-ntfy
    ];
    # ============================================================================
    # OPTIONS - Define what can be configured
    # ============================================================================
    options = {
      services.ntfy-nixlab = {
        # REQUIRED: Enable the service
        enable = lib.mkEnableOption "ntfy push notification server";

        # OPTIONAL: Port to listen on (default: 2586)
        port = lib.mkOption {
          type = lib.types.port;
          default = 2586;
          description = "Port for ntfy to listen on";
        };

        # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
        };

        # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "ntfy.example.com";
          description = "Domain name for nginx reverse proxy (optional)";
        };

        # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
        enableSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HTTPS with Let's Encrypt (requires domain)";
        };

        # OPTIONAL: Where to store ntfy data (default: /var/lib/ntfy)
        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/ntfy";
          example = "/data/ntfy";
          description = "Directory for ntfy data storage (cache database, attachments)";
        };

        # OPTIONAL: ntfy package to use
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.ntfy-sh;
          defaultText = lib.literalExpression "pkgs.ntfy-sh";
          description = "The ntfy package to use";
        };

        # OPTIONAL: Auto-open firewall ports (default: true)
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open firewall ports";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "ntfy";
          description = "User to run ntfy as";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "ntfy";
          description = "Group to run ntfy as";
        };

        # OPTIONAL: allow opting out of the mainUser group membership
        # without coupling to a specific external option name
        extraUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["alice"];
          description = "Extra users to add to the ntfy group";
        };

        # ── Message cache ──────────────────────────────────────────────────────
        cacheDuration = lib.mkOption {
          type = lib.types.str;
          default = "12h";
          example = "24h";
          description = "How long published messages are buffered in the cache";
        };

        cacheFile = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "/var/lib/ntfy/cache.db";
          description = ''
            Path to the SQLite cache database. Empty string uses the in-memory
            cache (messages are lost on restart). Set to a path under dataDir
            to persist messages across restarts.
          '';
        };

        # ── Attachments ────────────────────────────────────────────────────────
        attachments = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable file attachment support";
          };

          sizeLimit = lib.mkOption {
            type = lib.types.str;
            default = "15M";
            example = "50M";
            description = "Maximum size per attachment file";
          };

          totalSizeLimit = lib.mkOption {
            type = lib.types.str;
            default = "5G";
            example = "10G";
            description = "Maximum total size of all attachments combined";
          };

          expiryDuration = lib.mkOption {
            type = lib.types.str;
            default = "3h";
            example = "24h";
            description = "How long attachments are kept before being deleted";
          };
        };

        # ── Rate limiting ──────────────────────────────────────────────────────
        rateLimit = {
          globalTopicLimit = lib.mkOption {
            type = lib.types.int;
            default = 15000;
            description = "Total number of topics the server will allow";
          };

          subscriberRateLimit = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable rate limiting per subscriber IP";
          };
        };

        # ── Authentication ─────────────────────────────────────────────────────
        auth = {
          enable = lib.mkEnableOption "ntfy authentication and access control";

          defaultAccess = lib.mkOption {
            type = lib.types.enum ["deny-all" "read-write" "read-only" "write-only"];
            default = "deny-all";
            description = ''
              Default access policy for unauthenticated users.
              "deny-all" requires authentication for all operations.
              "read-write" allows anonymous publish and subscribe.
            '';
          };
        };

        # ── Web UI ─────────────────────────────────────────────────────────────
        enableWebUI = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the ntfy web interface";
        };

        # ── SMTP (email-to-ntfy) ───────────────────────────────────────────────
        smtp = {
          enable = lib.mkEnableOption "SMTP server for email-to-ntfy bridge";

          listenAddress = lib.mkOption {
            type = lib.types.str;
            default = "0.0.0.0:25";
            description = "Address and port for the SMTP listener";
          };

          domain = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "ntfy.example.com";
            description = "SMTP domain — must match the MX record for email-to-ntfy";
          };

          addrPrefix = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "ntfy-";
            description = ''
              Optional prefix for the SMTP address to disambiguate from other
              addresses on the same domain (e.g. "ntfy-" → ntfy-mytopic@example.com).
            '';
          };
        };

        # ── Firebase (optional upstream relay) ────────────────────────────────
        firebaseKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Path to a Firebase service account JSON key file. When set, ntfy
            will relay published messages to Firebase Cloud Messaging so that
            the official Android/iOS apps can receive push notifications even
            when the ntfy app is not running.
            Manage the file with sops-nix or agenix to keep it out of the store.
          '';
        };
      };
    };

    # ============================================================================
    # CONFIG - What happens when the service is enabled
    # ============================================================================
    config = lib.mkIf cfg.enable {
      # ============================================================================
      # ASSERTIONS - Catch invalid option combinations at eval time
      # ============================================================================
      assertions = [
        (nixlabLib.mkSslAssertion {
          inherit (cfg) enableSSL domain;
          moduleName = "services.ntfy-nixlab";
        })
        {
          assertion = !(cfg.smtp.enable && cfg.smtp.domain == "");
          message = ''
            services.ntfy-nixlab.smtp.enable requires services.ntfy-nixlab.smtp.domain
            to be set to the domain whose MX record points at this server.
          '';
        }
        {
          assertion = !(cfg.attachments.enable && cfg.cacheFile == "");
          message = ''
            services.ntfy-nixlab.attachments.enable requires a persistent cache.
            Set services.ntfy-nixlab.cacheFile to a path such as
            "${cfg.dataDir}/cache.db" so attachment metadata survives restarts.
          '';
        }
      ];

      # ----------------------------------------------------------------------------
      # DIRECTORY SETUP - Create necessary directories with proper permissions
      # ----------------------------------------------------------------------------
      systemd.tmpfiles.rules =
        [
          "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
        ]
        ++ lib.optionals cfg.attachments.enable [
          "d ${cfg.dataDir}/attachments 0750 ${cfg.user} ${cfg.group} -"
        ];

      # ----------------------------------------------------------------------------
      # USER SETUP - Create dedicated system user
      # ----------------------------------------------------------------------------
      users.users = lib.mkMerge (
        [
          {
            ${cfg.user} = {
              isSystemUser = true;
              group = cfg.group;
              home = cfg.dataDir;
              description = "ntfy service user";
            };
          }
        ]
        ++ lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
        (map (u: {${u} = {extraGroups = [cfg.group];};})
          ([config.nixlab.mainUser] ++ cfg.extraUsers))
      );

      users.groups.${cfg.group} = {};

      # ----------------------------------------------------------------------------
      # NTFY SERVICE - Configure the systemd service
      # ----------------------------------------------------------------------------
      systemd.services.ntfy = {
        description = "ntfy Push Notification Server";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];

        serviceConfig =
          nixlabLib.mkServiceHardening {
            writablePaths = [cfg.dataDir];
          }
          // {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            ExecStart = "${cfg.package}/bin/ntfy serve --config ${cfg.dataDir}/server.yml";
            Restart = "on-failure";
            RestartSec = "10s";
            # ntfy serves its own web UI from embedded assets — no additional
            # filesystem access beyond dataDir is required.
          }
          // lib.optionalAttrs (cfg.firebaseKeyFile != null) {
            # Expose the key path as an env var so the config can reference it
            # without baking the store path into the YAML.
            Environment = "NTFY_FIREBASE_KEY_FILE=${cfg.firebaseKeyFile}";
          };

        preStart = let
          # Build the server config as a Nix attrset then serialise to YAML
          # via remarshal — same pattern as the Loki module.
          baseConfig = {
            base-url =
              if cfg.domain != null
              then "${
                if cfg.enableSSL
                then "https"
                else "http"
              }://${cfg.domain}"
              else "http://${cfg.listenAddress}:${toString cfg.port}";

            listen-http = "${cfg.listenAddress}:${toString cfg.port}";

            cache-duration = cfg.cacheDuration;

            global-topic-limit = cfg.rateLimit.globalTopicLimit;
            visitor-subscription-limit = 30;
            visitor-request-limit-burst = 60;
            visitor-request-limit-replenish = "5s";

            enable-signup = false;
            enable-login = cfg.auth.enable;
            enable-reservations = cfg.auth.enable;
          };

          cacheConfig = lib.optionalAttrs (cfg.cacheFile != "") {
            cache-file = cfg.cacheFile;
          };

          attachmentConfig = lib.optionalAttrs cfg.attachments.enable {
            attachment-cache-dir = "${cfg.dataDir}/attachments";
            attachment-file-size-limit = cfg.attachments.sizeLimit;
            attachment-total-size-limit = cfg.attachments.totalSizeLimit;
            attachment-expiry-duration = cfg.attachments.expiryDuration;
          };

          authConfig = lib.optionalAttrs cfg.auth.enable {
            auth-file = "${cfg.dataDir}/user.db";
            auth-default-access = cfg.auth.defaultAccess;
          };

          webConfig = lib.optionalAttrs (!cfg.enableWebUI) {
            web-root = "disable";
          };

          smtpConfig = lib.optionalAttrs cfg.smtp.enable (
            {
              smtp-server-listen = cfg.smtp.listenAddress;
              smtp-server-domain = cfg.smtp.domain;
            }
            // lib.optionalAttrs (cfg.smtp.addrPrefix != "") {
              smtp-server-addr-prefix = cfg.smtp.addrPrefix;
            }
          );

          firebaseConfig = lib.optionalAttrs (cfg.firebaseKeyFile != null) {
            # The actual path is injected via the Environment= unit directive
            # above; this key tells ntfy to look for it in the environment.
            firebase-key-file = "\${NTFY_FIREBASE_KEY_FILE}";
          };

          subscriberRateConfig = lib.optionalAttrs cfg.rateLimit.subscriberRateLimit {
            visitor-subscriber-rate-limiting = true;
          };

          serverConfig =
            baseConfig
            // cacheConfig
            // attachmentConfig
            // authConfig
            // webConfig
            // smtpConfig
            // firebaseConfig
            // subscriberRateConfig;

          jsonFile =
            builtins.toFile "ntfy-server.json"
            (builtins.toJSON serverConfig);

          yamlTmp = "${cfg.dataDir}/server.yml.tmp";
        in ''
          ${pkgs.remarshal}/bin/remarshal \
            -i ${jsonFile} \
            -o ${yamlTmp} \
            -if json \
            -of yaml

          install -m 640 -o ${cfg.user} -g ${cfg.group} ${yamlTmp} ${cfg.dataDir}/server.yml
        '';
      };

      # ----------------------------------------------------------------------------
      # NGINX REVERSE PROXY - Only configured if domain is set
      # ----------------------------------------------------------------------------
      services.nginx.enable = lib.mkIf (cfg.domain != null) true;
      services.nginx.virtualHosts = nixlabLib.mkNginxVirtualHost {
        inherit (cfg) domain listenAddress port enableSSL;
        extraConfig = ''
          # ntfy requires long-lived connections for SSE/WebSocket subscriptions
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";

          # Disable buffering so SSE messages are flushed immediately
          proxy_buffering off;
          proxy_read_timeout 1800s;
          proxy_send_timeout 1800s;

          # Allow large attachment uploads
          client_max_body_size 50M;
        '';
      };

      # ----------------------------------------------------------------------------
      # FIREWALL - Open necessary ports if requested
      # ----------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts =
        lib.mkIf cfg.openFirewall
        (nixlabLib.mkFirewallPorts {
            inherit (cfg) domain listenAddress;
            servicePort = cfg.port;
          }
          ++ lib.optionals cfg.smtp.enable [25]);
    };
  };
}
/*
================================================================================
USAGE EXAMPLES
================================================================================

Minimal (localhost only, no auth, in-memory cache):
----------------------------------------------------
services.ntfy-nixlab = {
  enable = true;
};
# Access at: http://127.0.0.1:2586


With domain and SSL (recommended for internet-facing):
------------------------------------------------------
services.ntfy-nixlab = {
  enable = true;
  domain    = "ntfy.example.com";
  enableSSL = true;

  # Persist messages across restarts
  cacheFile    = "/var/lib/ntfy/cache.db";
  cacheDuration = "24h";
};


With authentication enabled (deny-all default):
-----------------------------------------------
services.ntfy-nixlab = {
  enable    = true;
  domain    = "ntfy.example.com";
  enableSSL = true;
  cacheFile = "/var/lib/ntfy/cache.db";

  auth = {
    enable        = true;
    defaultAccess = "deny-all";   # or "read-only" for public read
  };
};

# After first start, add users via:
#   sudo -u ntfy ntfy user add --role=admin myuser
#   sudo -u ntfy ntfy user add myreader
#   sudo -u ntfy ntfy access myreader mytopic read


With file attachments:
----------------------
services.ntfy-nixlab = {
  enable    = true;
  domain    = "ntfy.example.com";
  enableSSL = true;
  cacheFile = "/var/lib/ntfy/cache.db";

  attachments = {
    enable           = true;
    sizeLimit        = "25M";
    totalSizeLimit   = "10G";
    expiryDuration   = "6h";
  };
};


With email-to-ntfy SMTP bridge:
--------------------------------
services.ntfy-nixlab = {
  enable    = true;
  domain    = "ntfy.example.com";
  enableSSL = true;
  cacheFile = "/var/lib/ntfy/cache.db";

  smtp = {
    enable        = true;
    listenAddress = "0.0.0.0:25";
    domain        = "ntfy.example.com";
    addrPrefix    = "ntfy-";  # send to ntfy-mytopic@ntfy.example.com
  };
};
# Ensure port 25 is open and your MX record points here.
# Email sent to ntfy-<topic>@ntfy.example.com publishes to <topic>.


Full configuration:
-------------------
services.ntfy-nixlab = {
  enable        = true;
  port          = 2586;
  listenAddress = "127.0.0.1";
  domain        = "ntfy.example.com";
  enableSSL     = true;

  cacheFile     = "/var/lib/ntfy/cache.db";
  cacheDuration = "24h";

  dataDir = "/data/ntfy";

  attachments = {
    enable         = true;
    sizeLimit      = "50M";
    totalSizeLimit = "20G";
    expiryDuration = "12h";
  };

  auth = {
    enable        = true;
    defaultAccess = "deny-all";
  };

  rateLimit = {
    globalTopicLimit    = 25000;
    subscriberRateLimit = true;
  };

  # Firebase key managed by sops-nix
  firebaseKeyFile = config.sops.secrets.ntfy-firebase-key.path;

  openFirewall = true;
};


================================================================================
INITIAL SETUP
================================================================================

1. Verify ntfy is running:
   curl http://localhost:2586/v1/health
   # Returns: {"healthy":true}

2. Publish a test message:
   curl -d "Hello from ntfy" http://localhost:2586/test-topic

3. Subscribe via SSE (keep open in a terminal):
   curl -s http://localhost:2586/test-topic/sse

4. If auth is enabled, create the admin user first:
   sudo -u ntfy ntfy user add --role=admin admin
   # then use -u admin:password in curl or the web UI

5. View the web UI (if enableWebUI = true):
   http://localhost:2586  (or your domain)


================================================================================
PROMETHEUS INTEGRATION
================================================================================

ntfy exposes metrics at /metrics (Prometheus format).
Add to your prometheus-nixlab scrape configs:

  scrape_configs:
    - job_name: "ntfy"
      static_configs:
        - targets: ["localhost:2586"]
      metrics_path: /metrics
      # If auth is enabled, supply credentials:
      # basic_auth:
      #   username: prometheus
      #   password_file: /run/secrets/ntfy-prometheus-password


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status ntfy

View logs:
  sudo journalctl -u ntfy -f

Inspect the generated config:
  sudo cat /var/lib/ntfy/server.yml

List users (if auth enabled):
  sudo -u ntfy ntfy user list

Check access control:
  sudo -u ntfy ntfy access

Test publish (no auth):
  curl -d "test" http://localhost:2586/my-topic

Test publish (with auth):
  curl -u user:pass -d "test" http://localhost:2586/my-topic

Common issues:
  - 403 Forbidden:    Auth is enabled; check credentials and topic ACLs
  - SSE disconnects:  Verify proxy_read_timeout in nginx (needs to be high)
  - Attachments fail: Ensure cacheFile is set (required for attachment support)
  - Port 25 blocked:  Many cloud providers block port 25; check security groups
*/

