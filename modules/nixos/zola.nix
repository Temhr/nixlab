{self, ...}: {
  flake.nixosModules.servc--zola-nixlab = {
    config,
    lib,
    pkgs,
    nixlabLib,
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

    # When configToml is set, serialise the merged attrset to a TOML file in
    # the Nix store via pkgs.formats.toml (the same mechanism used by
    # services.prometheus, services.grafana, etc.).
    #
    # base_url is always injected last so it matches effectiveBaseUrl regardless
    # of what the user wrote in configToml — or didn't write at all.
    #
    # The store path is immutable and world-readable, safe to reference from
    # ExecStartPre.  Only evaluated when configToml != null.
    configFile =
      if cfg.configToml != null
      then
        (pkgs.formats.toml {}).generate "zola-config.toml"
        (cfg.configToml // {base_url = effectiveBaseUrl;})
      else null;
  in {
    imports = [
      self.nixosModules.systm--ports-zola
    ];
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

        # OPTIONAL: Additional users to add to the zola group.
        # The primary nixlab user is added automatically via config.nixlab.mainUser.
        extraUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["alice"];
          description = "Extra users to add to the zola group (allows siteDir access).";
        };

        # OPTIONAL: Declarative config.toml as a Nix attribute set (default: null).
        #
        # When set, the module serialises this to TOML via pkgs.formats.toml and
        # installs it into siteDir on every service start, fully replacing whatever
        # config.toml is on disk. This is the recommended approach for reproducible,
        # version-controlled site configuration.
        #
        # NOTE: base_url is always injected/overridden by the module using
        # effectiveBaseUrl (derived from domain/enableSSL/baseUrl options).
        # You do not need to set it here — any value you provide will be ignored.
        #
        # When null (default) the module does NOT manage config.toml at all.
        # A config.toml must already exist in siteDir (e.g. created via `zola init`)
        # or the preStart check will fail and the service will not start.
        configToml = lib.mkOption {
          type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
          default = null;
          description = "Declarative config.toml as a Nix attrset. base_url is always injected by the module and need not be set here.";
        };

        # OPTIONAL: Path to a file containing environment variables (default: null).
        # The file is sourced into the zola service environment before start.
        # Useful for secrets (API keys in theme templates, deploy hooks, etc.)
        # that should not live in the Nix store.
        # File format: KEY=value, one per line (systemd EnvironmentFile syntax).
        secretsEnvFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = "/run/secrets/zola-env";
          description = "Path to an EnvironmentFile with secrets injected into the zola service environment.";
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
        (nixlabLib.mkSslAssertion {
          inherit (cfg) enableSSL domain;
          moduleName = "services.zola-nixlab";
        })
      ];

      # ----------------------------------------------------------------------------
      # USER SETUP - Dedicated system user/group for Zola
      # ----------------------------------------------------------------------------
      users.groups.zola = {};

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
        ++ lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
        (map (u: {${u} = {extraGroups = ["zola"];};})
          ([config.nixlab.mainUser] ++ cfg.extraUsers))
      );

      # ----------------------------------------------------------------------------
      # SITE SCAFFOLDING - Only runs when configToml is NOT set
      # ----------------------------------------------------------------------------
      # When configToml is set the module fully manages config.toml via
      # ExecStartPre (see the systemd service below), so activation-time
      # scaffolding is not needed and would conflict.
      #
      # When configToml is null the user owns config.toml entirely. We still
      # scaffold the directory structure on first activation so that a bare
      # siteDir is usable immediately, but we never overwrite an existing file.
      system.activationScripts.initZolaSite = lib.mkIf (cfg.configToml == null) {
        text = ''
                    SITE_DIR="${cfg.siteDir}"

                    if [ ! -f "$SITE_DIR/config.toml" ]; then
                      echo "Initializing Zola site scaffold at $SITE_DIR..."
                      mkdir -p "$SITE_DIR"/{content,templates,static,themes}

                      cat > "$SITE_DIR/content/_index.md" << 'EOF'
          +++
          title = "Home"
          +++

          # Welcome!

          This is my Zola site. Edit siteDir and add a config.toml to get started.
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
                      echo "Scaffold created. Add a config.toml or set services.zola-nixlab.configToml."
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

        serviceConfig =
          nixlabLib.mkServiceHardening {
            writablePaths = [cfg.siteDir];
          }
          // {
            Type = "simple";
            User = "zola";
            Group = "zola";
            WorkingDirectory = cfg.siteDir;

            # ExecStartPre commands run before ExecStart in order.
            #
            # Step 1 (root, '+' prefix): install config.toml from the Nix store
            # when configToml is set. The '+' prefix runs this specific command
            # as root regardless of User = zola above — the correct way to do a
            # privileged pre-start action under systemd hardening without the
            # deprecated PermissionsStartOnly. Only present when configToml != null.
            #
            # Step 2 (zola user): guard against a missing config.toml. Catches
            # the case where configToml is null and the user hasn't created one,
            # or where siteDir is a mount that isn't present yet.
            ExecStartPre =
              lib.optional (cfg.configToml != null)
              "+${pkgs.coreutils}/bin/install -m 640 -o zola -g zola ${configFile} ${cfg.siteDir}/config.toml"
              ++ [
                "${pkgs.bash}/bin/bash -c 'if [ ! -f ${cfg.siteDir}/config.toml ]; then echo \"ERROR: no config.toml at ${cfg.siteDir} — set configToml or create one manually\"; exit 1; fi'"
              ];

            # The --base-url flag always mirrors effectiveBaseUrl so it stays in
            # sync with whatever nginx / the domain options say, even if the
            # on-disk config.toml has a different value.
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
              # watchMode = false: --watch-only tells Zola to rebuild on changes
              # but not run its own HTTP server (hand off serving to nginx).
              # watchMode = true (default): serve + live-reload normally.
              ++ lib.optionals (!cfg.watchMode) ["--watch-only"]
              ++ cfg.extraArgs
            );

            Restart = "on-failure";
            RestartSec = "10s";
          }
          // lib.optionalAttrs (cfg.secretsEnvFile != null) {
            EnvironmentFile = cfg.secretsEnvFile;
          };
      };

      # ----------------------------------------------------------------------------
      # NGINX REVERSE PROXY - Only configured if domain is set
      # ----------------------------------------------------------------------------
      services.nginx.enable = lib.mkIf (cfg.domain != null) true;

      services.nginx.virtualHosts = nixlabLib.mkNginxVirtualHost {
        inherit (cfg) domain listenAddress port enableSSL;
        extraConfig = ''
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        '';
      };

      # ----------------------------------------------------------------------------
      # FIREWALL - Open necessary ports when requested
      # ----------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts =
        lib.mkIf cfg.openFirewall
        (nixlabLib.mkFirewallPorts {
          inherit (cfg) domain listenAddress;
          servicePort = cfg.port;
        });
    };
  };
}
/*
================================================================================
USAGE EXAMPLES
================================================================================

Minimal (localhost only, user-managed config.toml):
----------------------------------------------------
services.zola-nixlab = {
  enable = true;
  siteDir = "/var/www/my-blog";
  # config.toml must already exist in siteDir (e.g. from `zola init`)
};
# Access at: http://localhost:3003


Declarative config.toml (recommended):
---------------------------------------
services.zola-nixlab = {
  enable = true;
  siteDir = "/var/www/my-blog";
  # base_url is always injected automatically — do not set it here.
  configToml = {
    title = "My Blog";
    compile_sass = true;
    build_search_index = true;
    markdown = { highlight_code = true; };
    extra = { author = "Alice"; };
  };
};
# config.toml is written from the Nix store on every service start.
# Rebuild and switch to update the live config.


Full configuration with nginx + SSL:
-------------------------------------
services.zola-nixlab = {
  enable = true;
  siteDir = "/var/www/my-blog";
  port = 3003;
  listenAddress = "127.0.0.1";  # nginx proxies; no need to expose directly
  watchMode = true;              # auto-rebuild on content changes

  configToml = {
    title = "My Blog";
    compile_sass = true;
    build_search_index = true;
    markdown = { highlight_code = true; };
  };

  domain = "blog.example.com";
  enableSSL = true;              # provisions a Let's Encrypt cert via ACME
  openFirewall = true;           # opens 80 + 443

  extraUsers = ["alice"];        # grant alice rw access to siteDir

  secretsEnvFile = "/run/secrets/zola-env";  # KEY=value file, not in store
};


Network access without proxy:
------------------------------
services.zola-nixlab = {
  enable = true;
  siteDir = "/var/www/my-blog";
  listenAddress = "0.0.0.0";
  openFirewall = true;
};
# Access at: http://your-ip:3003


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
  config.toml    - Managed by configToml option, or created manually
  content/       - Markdown content files
  templates/     - Tera HTML templates
  static/        - Static assets (images, CSS, JS)
  themes/        - Optional themes

Create a site manually (when not using configToml):
  zola init /var/www/my-blog


================================================================================
WATCH MODE
================================================================================

watchMode = true (default):
  - zola serve watches the filesystem and rebuilds on every change.
  - Ideal for development and content-heavy workflows.

watchMode = false:
  - Passes --watch-only; Zola watches and rebuilds but its HTTP server is
    suppressed. Pair with nginx serving public/ for a production setup.


================================================================================
DECLARATIVE vs MANUAL config.toml
================================================================================

configToml set:
  - The Nix attrset is serialised to TOML in the store at build time.
  - On every service start, ExecStartPre (as root) installs it into siteDir,
    fully replacing whatever was there. Changes take effect after nixos-rebuild.
  - base_url is always injected by the module; you never need to set it.

configToml = null (default):
  - The module does not touch config.toml. You own it entirely.
  - A preStart check will refuse to start if config.toml is missing.
  - Use `zola init /path/to/siteDir` to create an initial site.


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

