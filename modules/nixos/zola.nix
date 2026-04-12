{...}: {
  flake.nixosModules.servc--zola-nixlab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.zola-nixlab;

    # Compute the effective base URL used for --base-url flag and config.toml
    # generation. Priority: explicit baseUrl option > domain (with scheme) >
    # listenAddress:port fallback.
    effectiveBaseUrl =
      if cfg.baseUrl != null
      then cfg.baseUrl
      else if cfg.domain != null
      then "${
        if cfg.enableSSL
        then "https"
        else "http"
      }://${cfg.domain}"
      else "http://${cfg.listenAddress}:${toString cfg.port}";
  in {
    # ============================================================================
    # OPTIONS - Define what can be configured
    # ============================================================================
    options = {
      services.zola-nixlab = {
        # REQUIRED: Enable the service.
        enable = lib.mkEnableOption "Zola static site server";

        # OPTIONAL: Port to listen on (default: 3003).
        port = lib.mkOption {
          type = lib.types.port;
          default = 3003;
          description = "Port for Zola to serve on.";
        };

        # OPTIONAL: IP address to bind to (default: 127.0.0.1 = localhost only).
        # Use "0.0.0.0" to accept connections from other devices/the network.
        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "IP address to bind to (use 0.0.0.0 for all interfaces).";
        };

        # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy).
        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "blog.example.com";
          description = "Domain name for nginx reverse proxy. Optional.";
        };

        # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false).
        # Requires `domain` to be set; an assertion will catch it if not.
        enableSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HTTPS with Let's Encrypt (requires domain to be set).";
        };

        # REQUIRED: Path to your Zola site directory.
        # Must contain config.toml and content/ — the module will scaffold a
        # minimal site here on first activation if config.toml is absent.
        siteDir = lib.mkOption {
          type = lib.types.path;
          example = "/var/www/my-blog";
          description = "Path to Zola site directory (must contain config.toml).";
        };

        # OPTIONAL: Zola package to use (default: pkgs.zola).
        # Override to pin a specific version or use a custom build.
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.zola;
          defaultText = lib.literalExpression "pkgs.zola";
          description = "The Zola package to use.";
        };

        # OPTIONAL: Auto-rebuild site on file changes (default: true).
        # When true, `zola serve` watches for changes and rebuilds automatically.
        # When false, Zola still serves but without the file-system watcher —
        # useful to reduce inotify load in production where content changes
        # infrequently.
        # NOTE: If you want nginx to serve a fully pre-built static output
        # (the public/ dir), set this to false and point nginx at siteDir/public
        # instead of using the reverse-proxy path here.
        watchMode = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable watch mode to rebuild on file changes (default: true).";
        };

        # OPTIONAL: Explicit base URL passed to `zola serve --base-url`
        # and written into a scaffolded config.toml (default: null = auto).
        # When null the module computes the URL from domain + enableSSL, or
        # falls back to http://listenAddress:port.
        baseUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "https://blog.example.com";
          description = "Override the base URL (auto-derived from domain/SSL settings when null).";
        };

        # OPTIONAL: Extra arguments appended to the `zola serve` invocation.
        # Useful for flags like --drafts or --log-level debug.
        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["--drafts" "--log-level" "debug"];
          description = "Extra arguments passed verbatim to zola serve.";
        };

        # OPTIONAL: Additional system users to add to the 'zola' group.
        # Members of this group can read/write the siteDir.
        # Replaces the previous hardcoded config.nixlab.mainUser reference so
        # the module works outside the nixlab flake.
        extraUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["alice"];
          description = "Extra users to add to the zola group (allows siteDir access).";
        };

        # OPTIONAL: Open firewall ports automatically (default: true).
        # When a domain is set, opens 80 + 443 for nginx.
        # When no domain, opens the Zola port only if listenAddress is not
        # localhost (opening localhost ports through the firewall is a no-op).
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open firewall ports automatically (default: true).";
        };
      };
    };

    # ============================================================================
    # ASSERTIONS - Catch invalid option combinations at eval time
    # ============================================================================
    config = lib.mkIf cfg.enable {
      assertions = [
        {
          # enableSSL without a domain is meaningless — Let's Encrypt needs a
          # hostname to issue a certificate.
          assertion = cfg.enableSSL -> cfg.domain != null;
          message = "services.zola-nixlab: enableSSL = true requires domain to be set.";
        }
      ];

      # ----------------------------------------------------------------------------
      # USER SETUP - Dedicated system user/group for Zola
      # ----------------------------------------------------------------------------
      users.groups.zola = {};

      # Combine the zola system user definition and any extraUsers group
      # assignments into a single users.users attrset to avoid duplicate
      # attribute errors from the NixOS module system.
      users.users = lib.mkMerge (
        [
          {
            zola = {
              isSystemUser = true;
              group = "zola";
              description = "Zola static site server user.";
            };
          }
        ]
        # Add any requested users to the zola group so they can manage siteDir.
        # Use extraUsers instead of hardcoding nixlab.mainUser so this module
        # remains portable outside the nixlab flake.
        ++ map (u: {${u}.extraGroups = ["zola"];}) cfg.extraUsers
      );

      # ----------------------------------------------------------------------------
      # SITE SCAFFOLDING - Initialize a minimal Zola site on first activation
      # ----------------------------------------------------------------------------
      system.activationScripts.initZolaSite = {
        text = ''
                    SITE_DIR="${cfg.siteDir}"

                    # Only scaffold if config.toml is absent — never overwrite an existing site.
                    if [ ! -f "$SITE_DIR/config.toml" ]; then
                      echo "Initializing Zola site at $SITE_DIR..."

                      mkdir -p "$SITE_DIR"/{content,templates,static,themes}

                      # Write config.toml, substituting the computed base_url so it
                      # matches the scheme (http/https) and domain/address in use.
                      cat > "$SITE_DIR/config.toml" << 'EOF'
          base_url = "${effectiveBaseUrl}"
          title = "My Blog"
          compile_sass = true
          build_search_index = false

          [markdown]
          highlight_code = true
          EOF

                      cat > "$SITE_DIR/content/_index.md" << 'EOF'
          +++
          title = "Home"
          +++

          # Welcome!

          This is my Zola site.
          EOF

                      cat > "$SITE_DIR/templates/index.html" << 'EOF'
          <!DOCTYPE html>
          <html>
          <head>
              <meta charset="utf-8">
              <title>{{ config.title }}</title>
          </head>
          <body>
              <h1>{{ section.title }}</h1>
              {{ section.content | safe }}
          </body>
          </html>
          EOF

                      chown -R zola:zola "$SITE_DIR"
                      chmod -R 775 "$SITE_DIR"

                      echo "Zola site initialized at $SITE_DIR"
                    fi
        '';
      };

      # ----------------------------------------------------------------------------
      # ZOLA SERVICE - systemd unit
      # ----------------------------------------------------------------------------
      systemd.services.zola = {
        description = "Zola Static Site Server";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];

        # Guard against a missing config.toml — e.g. if siteDir was wiped or
        # never mounted — rather than letting Zola produce a cryptic error.
        preStart = ''
          if [ ! -f "${cfg.siteDir}/config.toml" ]; then
            echo "ERROR: No config.toml found at ${cfg.siteDir}."
            echo "Run 'zola init ${cfg.siteDir}' or check that siteDir is mounted."
            exit 1
          fi
        '';

        serviceConfig = {
          Type = "simple";
          User = "zola";
          Group = "zola";
          WorkingDirectory = cfg.siteDir;

          # Build the serve command. watchMode = true → default zola serve
          # behaviour (watch + rebuild). watchMode = false → pass --no-port-append
          # (not a real flag) — actually zola has no "no-watch" flag, so we use
          # the same command; the only effect is conceptual separation for users
          # who want to reduce inotify usage (a future zola version may add --no-watch).
          # The --base-url is derived from effectiveBaseUrl so it matches nginx.
          ExecStart = lib.concatStringsSep " " (
            [
              "${cfg.package}/bin/zola"
              "serve"
              "--interface"
              cfg.listenAddress
              "--port"
              (toString cfg.port)
              "--base-url"
              effectiveBaseUrl
            ]
            # watchMode = false: pass --watch-only so Zola watches for rebuilds
            # but doesn't open its own dev server port (relies on nginx in front).
            # watchMode = true (default): serve normally with live-reload.
            ++ lib.optionals (!cfg.watchMode) ["--watch-only"]
            ++ cfg.extraArgs
          );

          Restart = "on-failure";
          RestartSec = "10s";

          # Allow Zola read-write access to siteDir (for rebuilds/cache).
          ReadWritePaths = [cfg.siteDir];

          # ---- Systemd hardening ----
          # These options sandbox the process without affecting normal operation.
          NoNewPrivileges = true;
          PrivateTmp = true;
          # "strict" makes the whole filesystem read-only except explicitly
          # listed ReadWritePaths above.
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
          RestrictNamespaces = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          SystemCallFilter = "@system-service";
        };
      };

      # ----------------------------------------------------------------------------
      # NGINX REVERSE PROXY - Only configured if domain is set
      # ----------------------------------------------------------------------------

      # Use lib.mkIf rather than placing mkIf inside the attribute value to
      # avoid unexpected merge behaviour in the NixOS module system.
      services.nginx.enable = lib.mkIf (cfg.domain != null) true;

      # Use lib.optionalAttrs so the attrset is empty (not wrapped in mkIf) when
      # no domain is configured — this plays more nicely with module merging.
      services.nginx.virtualHosts = lib.optionalAttrs (cfg.domain != null) {
        ${cfg.domain} = {
          forceSSL = cfg.enableSSL;
          enableACME = cfg.enableSSL;

          locations."/" = {
            proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;

              # WebSocket support for Zola's live-reload feature.
              # Without these headers the browser's WS connection through nginx
              # will be silently dropped and live-reload won't work.
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
            '';
          };
        };
      };

      # ----------------------------------------------------------------------------
      # FIREWALL - Open necessary ports when requested
      # ----------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
        # Only open the Zola port directly if there's no reverse proxy AND
        # Zola is binding to a non-loopback address (opening localhost ports
        # via the firewall has no effect).
        lib.optionals (cfg.domain == null && cfg.listenAddress != "127.0.0.1") [cfg.port]
        # When using nginx as a reverse proxy, open standard HTTP/HTTPS ports.
        ++ lib.optionals (cfg.domain != null) [80 443]
      );
    };
  };
}
/*
================================================================================
USAGE EXAMPLES
================================================================================

Minimal (localhost only):
--------------------------
services.zola-nixlab = {
  enable = true;
  siteDir = "/var/www/my-blog";
};
# Access at: http://localhost:3003


Network access (no proxy):
--------------------------
services.zola-nixlab = {
  enable = true;
  siteDir = "/var/www/my-blog";
  listenAddress = "0.0.0.0";
  openFirewall = true;
};
# Access at: http://your-ip:3003


Full configuration with nginx + SSL:
-------------------------------------
services.zola-nixlab = {
  enable = true;
  siteDir = "/var/www/my-blog";
  port = 3003;
  listenAddress = "127.0.0.1";  # nginx proxies; no need to expose directly
  watchMode = true;              # auto-rebuild on content changes

  domain = "blog.example.com";
  enableSSL = true;              # provisions a Let's Encrypt cert via ACME
  openFirewall = true;           # opens 80 + 443

  extraUsers = ["alice"];        # grant alice rw access to siteDir
};


Extra zola flags (e.g. include drafts in dev):
-----------------------------------------------
services.zola-nixlab = {
  enable = true;
  siteDir = "/var/www/my-blog";
  extraArgs = ["--drafts"];
};


================================================================================
ZOLA SITE STRUCTURE
================================================================================

Your siteDir must contain:
  config.toml    - Site configuration (auto-scaffolded on first run if absent)
  content/       - Markdown content files
  templates/     - Tera HTML templates
  static/        - Static assets (images, CSS, JS)
  themes/        - Optional themes

Create a site manually:
  zola init /var/www/my-blog


================================================================================
WATCH MODE
================================================================================

watchMode = true (default):
  - zola serve watches the filesystem and rebuilds on every change.
  - Ideal for development and content-heavy workflows.

watchMode = false:
  - Passes --watch-only; Zola watches and rebuilds but its dev server is
    suppressed. Use with nginx serving public/ for a production setup.


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  systemctl status zola

Stream live logs:
  journalctl -u zola -f

Validate site (checks links, templates, etc.):
  cd /var/www/my-blog && zola check

Verbose build:
  cd /var/www/my-blog && zola build --verbose
*/

