{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.servc--hermes-nixlab = {
    config,
    lib,
    pkgs,
    nixlabLib,
    ...
  }: let
    cfg = config.services.nixlab-hermes;

    hermesStateDir = "/var/lib/hermes";
    hermesEnvDir = "${hermesStateDir}/.hermes";
    hermesEnvFile = "${hermesEnvDir}/.env";

    # Fixed internal-only port the dashboard process itself binds to on
    # loopback. Deliberately distinct from cfg.dashboard.port (the
    # externally-facing port used by the socat forwarder / nginx): binding
    # a wildcard address (0.0.0.0) and a specific address (127.0.0.1) on
    # the *same* port number is not just "different addresses" — the
    # wildcard bind overlaps the specific one at the kernel level and one
    # of the two binds will fail with EADDRINUSE. Using different port
    # numbers for the internal app vs. the external forwarder sidesteps
    # this entirely.
    dashboardInternalPort = 19119;
  in {
    imports = [
      inputs.hermes-agent.nixosModules.default
      self.nixosModules.systm--ports-hermes
    ];

    # ============================================================================
    # OPTIONS
    # ============================================================================
    options.services.nixlab-hermes = {
      enable = lib.mkEnableOption "Hermes Agent (multi-agent supervisor/worker system)";

      model = {
        provider = lib.mkOption {
          type = lib.types.str;
          default = "custom";
          description = "Model provider identifier passed to hermes-agent's settings.model.provider.";
        };

        baseUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:11434/v1";
          description = "OpenAI-compatible base URL hermes-agent uses to reach the model backend.";
        };

        default = lib.mkOption {
          type = lib.types.str;
          default = "gemma4:e4b";
          description = "Default model name hermes-agent requests from the backend.";
        };
      };

      ollamaBaseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:11434";
        description = "Base URL of the Ollama API, exported to hermes-agent as OLLAMA_API_BASE.";
      };

      mcpServers = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = {};
        example = {
          filesystem = {
            command = "npx";
            args = ["-y" "@modelcontextprotocol/server-filesystem" "/srv"];
          };
        };
        description = "MCP server definitions passed through to services.hermes-agent.mcpServers.";
      };

      messagingEnvFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Path to a static env file with messaging-related secrets, merged into
          hermes-agent's environment via EnvironmentFile. Use agenix or sops-nix
          to provision this file. Distinct from the dynamically-minted Matrix
          token file managed by matrix.login below.
        '';
      };

      extraUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["alice"];
        description = "Extra users to add to the hermes-agent group, alongside nixlab.mainUser.";
      };

      matrix = {
        enable = lib.mkEnableOption "Matrix as a messaging channel for hermes-agent";

        login = {
          enable = lib.mkEnableOption "mint a fresh Matrix access token for hermes-agent at boot via password login";

          username = lib.mkOption {
            type = lib.types.str;
            description = "Matrix localpart to log in as, e.g. \"hermes-bot\".";
          };

          passwordFile = lib.mkOption {
            type = lib.types.path;
            description = "Path to a file containing the bare password (no KEY= prefix) for this account.";
          };

          homeserverUrl = lib.mkOption {
            type = lib.types.str;
            default = "http://127.0.0.1:6167";
            description = "Base URL of the homeserver to log in against.";
          };

          deviceId = lib.mkOption {
            type = lib.types.str;
            default = "hermes-agent";
            description = "Fixed device_id to reuse across boots, so repeated logins don't accumulate new devices.";
          };
        };
      };

      dashboard = {
        enable = lib.mkEnableOption "Hermes web UI dashboard";

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          example = "0.0.0.0";
          description = ''
            LAN-facing address to expose the dashboard on. The dashboard
            process itself always binds 127.0.0.1 internally — hermes-agent
            refuses to bind its own listener to a non-loopback address
            without an auth provider configured, so instead this module
            fronts it with nginx when listenAddress is non-loopback (or
            domain is set), and nginx is what actually binds here.
            basicAuth.enable is required whenever this is non-loopback.
          '';
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 9119;
          description = "Port the dashboard (and its nginx front door, if any) listens on.";
        };

        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "hermes.example.com";
          description = "Domain name for nginx reverse proxy (optional). If null and listenAddress is non-loopback, nginx still fronts the dashboard on listenAddress:port directly (no vhost/TLS).";
        };

        enableSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HTTPS with Let's Encrypt (requires domain to be set).";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Open firewall ports. Off by default — opt in deliberately.";
        };

        basicAuth = {
          enable = lib.mkEnableOption ''
            HTTP Basic Auth in front of the dashboard via nginx. Required
            whenever dashboard.listenAddress is non-loopback and
            allowUnauthenticatedLan is false, since the dashboard process
            itself never leaves loopback — nginx is the only thing standing
            between the LAN and an unauthenticated dashboard in that case
          '';

          htpasswdFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = ''
              Path to an htpasswd-format file (nginx's auth_basic_user_file).
              This is just a path — nginx reads it at request time, so it
              can point at a sops-nix or agenix secret and never touches the
              Nix store. Generate one with:

                nix shell nixpkgs#apacheHttpd -c htpasswd -c ./hermes-dashboard.htpasswd admin
            '';
          };
        };

        allowUnauthenticatedLan = lib.mkEnableOption ''
          exposing the dashboard on listenAddress with no authentication at
          all, relying entirely on your LAN/firewall as the trust boundary.
          nginx is still used (it's required to rewrite the HTTP Host header
          for hermes-agent's own DNS-rebinding check regardless of auth), it
          just won't have an auth_basic block — anyone who can reach
          listenAddress:port gets the dashboard, no login
        '';
      };
    };

    # ============================================================================
    # CONFIG
    # ============================================================================
    config = lib.mkIf cfg.enable {
      # --------------------------------------------------------------------------
      # ASSERTIONS — catch configuration mistakes at eval time
      # --------------------------------------------------------------------------
      assertions = [
        {
          assertion = cfg.dashboard.enableSSL -> cfg.dashboard.domain != null;
          message = "services.nixlab-hermes.dashboard.enableSSL requires dashboard.domain to be set";
        }
        {
          assertion = cfg.dashboard.enable && cfg.dashboard.listenAddress != "127.0.0.1" ->
            (cfg.dashboard.basicAuth.enable || cfg.dashboard.allowUnauthenticatedLan);
          message = ''
            services.nixlab-hermes.dashboard.listenAddress is set to a non-loopback
            address, but neither basicAuth.enable nor allowUnauthenticatedLan is set.
            The dashboard process itself always stays on loopback, so without one of
            these there would be nothing exposing it on the LAN at all. Pick one:
            basicAuth.enable = true (with htpasswdFile) for nginx + a login, or
            allowUnauthenticatedLan = true if you trust your LAN and just want a
            lightweight forwarder with no auth.
          '';
        }
        {
          assertion = cfg.dashboard.basicAuth.enable -> cfg.dashboard.basicAuth.htpasswdFile != null;
          message = "services.nixlab-hermes.dashboard.basicAuth.enable requires htpasswdFile to be set";
        }
        {
          assertion = cfg.matrix.login.enable -> cfg.matrix.enable;
          message = "services.nixlab-hermes.matrix.login.enable requires matrix.enable = true";
        }
        {
          assertion = cfg.matrix.login.enable -> builtins.pathExists cfg.matrix.login.passwordFile || true;
          # The path check is a hint; actual enforcement is at runtime
          message = "services.nixlab-hermes.matrix.login.passwordFile is set but the file may not exist at evaluation time — ensure it is provisioned before boot";
        }
      ];

      # --------------------------------------------------------------------------
      # DIRECTORIES
      # --------------------------------------------------------------------------
      # Ensures the state dir exists (and is owned correctly) before
      # hermes-matrix-login tries to write/chown the token file into it,
      # regardless of what order hermes-agent's own activation runs in.
      systemd.tmpfiles.rules = lib.mkIf cfg.matrix.login.enable [
        "d ${hermesStateDir} 0750 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} -"
        "d ${hermesEnvDir} 0750 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} -"
      ];

      # --------------------------------------------------------------------------
      # HERMES AGENT SERVICE
      # --------------------------------------------------------------------------
      systemd.services.hermes-agent.after =
        lib.optionals cfg.matrix.enable ["continuwuity.service" "matrix-nixlab-init-users.service"]
        ++ lib.optional cfg.matrix.login.enable "hermes-matrix-login.service";
      systemd.services.hermes-agent.wants =
        lib.optionals cfg.matrix.enable ["continuwuity.service" "matrix-nixlab-init-users.service"]
        ++ lib.optional cfg.matrix.login.enable "hermes-matrix-login.service";

      services.hermes-agent = {
        enable = true;

        # Confirmed real option — pulls the "matrix" pyproject extra into
        # the sealed venv, per the module source (uv-resolved, no PYTHONPATH
        # patching).
        extraDependencyGroups = lib.optionals cfg.matrix.enable ["matrix"];

        settings = {
          model = {
            provider = cfg.model.provider;
            base_url = cfg.model.baseUrl;
            default = cfg.model.default;
          };
          approvals.mode = "smart";
          approvals.cron_mode = "deny";
          delegation.orchestrator_enabled = true;
          delegation.max_spawn_depth = 2;
          # NOTE: unverified key path, same caveat as before — grep the venv
          # before trusting this if hermes-agent is ever upgraded.
          messaging.matrix.enabled = cfg.matrix.enable;
        };

        environment = {
          OLLAMA_API_BASE = cfg.ollamaBaseUrl;
        };

        mcpServers = cfg.mcpServers;

        environmentFiles =
          lib.optionals (cfg.messagingEnvFile != null) [(toString cfg.messagingEnvFile)];
      };

      # --------------------------------------------------------------------------
      # USERS
      # --------------------------------------------------------------------------
      users.users = lib.mkMerge (
        lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
        (map (u: {${u} = {extraGroups = [config.services.hermes-agent.group];};})
          ([config.nixlab.mainUser] ++ cfg.extraUsers))
      );

      # --------------------------------------------------------------------------
      # MATRIX LOGIN — mints a fresh access token at boot, opt-in
      # --------------------------------------------------------------------------
      systemd.services.hermes-matrix-login = lib.mkIf cfg.matrix.login.enable {
        description = "Log in as ${cfg.matrix.login.username} and mint a fresh Matrix access token for hermes-agent";
        after = ["continuwuity.service" "matrix-nixlab-init-users.service" "network-online.target"];
        wants = ["continuwuity.service" "matrix-nixlab-init-users.service" "network-online.target"];
        wantedBy = ["multi-user.target"];
        path = [pkgs.curl pkgs.jq];

        serviceConfig = lib.mkMerge [
          (nixlabLib.mkServiceHardening {
            writablePaths = [hermesEnvDir];
          })
          {
            Type = "oneshot";
            RemainAfterExit = true;
            LoadCredential = ["login_pw:${cfg.matrix.login.passwordFile}"];
          }
        ];

        script = let
          base = cfg.matrix.login.homeserverUrl;
        in ''
          set -eu
          pass=$(cat "$CREDENTIALS_DIRECTORY/login_pw")

          for i in $(seq 1 30); do
            curl -sS -o /dev/null "${base}/_matrix/client/versions" && break
            sleep 1
          done

          resp=$(curl -sS -X POST "${base}/_matrix/client/v3/login" \
            -H 'Content-Type: application/json' \
            -d "{\"type\":\"m.login.password\",\"identifier\":{\"type\":\"m.id.user\",\"user\":\"${cfg.matrix.login.username}\"},\"password\":\"$pass\",\"device_id\":\"${cfg.matrix.login.deviceId}\",\"initial_device_display_name\":\"hermes-agent\"}")

          token=$(echo "$resp" | jq -r '.access_token // empty')
          user_id=$(echo "$resp" | jq -r '.user_id // empty')

          if [ -z "$token" ] || [ -z "$user_id" ]; then
            echo "login failed: $resp"
            exit 1
          fi

          # Strip any previous MATRIX_ACCESS_TOKEN/MATRIX_USER_ID lines (left over
          # from activation-time merge or a prior run of this unit), then append
          # the freshly minted values. This file is regenerated by NixOS activation
          # from the static sources, so this script must run *after* activation,
          # every boot, to layer the dynamic values back on top.
          if [ -f "${hermesEnvFile}" ]; then
            grep -v -E '^(MATRIX_ACCESS_TOKEN|MATRIX_USER_ID)=' "${hermesEnvFile}" > "${hermesEnvFile}.tmp"
          else
            : > "${hermesEnvFile}.tmp"
          fi
          printf 'MATRIX_ACCESS_TOKEN=%s\nMATRIX_USER_ID=%s\n' "$token" "$user_id" >> "${hermesEnvFile}.tmp"
          mv "${hermesEnvFile}.tmp" "${hermesEnvFile}"
          chown ${config.services.hermes-agent.user}:${config.services.hermes-agent.group} "${hermesEnvFile}"
          chmod 0640 "${hermesEnvFile}"
          echo "logged in as $user_id, updated ${hermesEnvFile}"
        '';
      };

      # --------------------------------------------------------------------------
      # DASHBOARD - web UI, opt-in via dashboard.enable
      # --------------------------------------------------------------------------
      # NOTE: --skip-build assumes the web UI's `dist` directory is already
      # built into the hermes-agent package. If it isn't (i.e. this package
      # never ran `npm run build` at build time), the dashboard will serve a
      # stale/missing UI. Check web/dist exists under the package's share dir
      # before relying on this in production, and if not, this needs a
      # different approach (pre-build step in the Nix package, or dropping
      # --skip-build and ensuring npm/node are on PATH for the unit instead).
      systemd.services.hermes-dashboard = lib.mkIf cfg.dashboard.enable {
        description = "Hermes web UI dashboard";
        after = ["hermes-agent.service"];
        wants = ["hermes-agent.service"];
        wantedBy = ["multi-user.target"];

        serviceConfig =
          nixlabLib.mkServiceHardening {
            writablePaths = [];
          }
          // {
            Type = "simple";
            User = config.services.hermes-agent.user;
            Group = config.services.hermes-agent.group;
            ExecStart = "${config.services.hermes-agent.package}/bin/hermes dashboard --host 127.0.0.1 --port ${toString dashboardInternalPort} --skip-build --no-open";
            Restart = "on-failure";
            RestartSec = 5;
          };
      };

      # --------------------------------------------------------------------------
      # NGINX — required for ANY off-loopback dashboard access, auth or not.
      # hermes-agent's dashboard validates the HTTP Host header against the
      # address it's actually bound to (127.0.0.1:dashboardInternalPort); a
      # raw TCP forwarder like socat can't rewrite that header, so nothing
      # but an HTTP-aware proxy can satisfy that check. basicAuth.enable vs.
      # allowUnauthenticatedLan only toggles whether an auth_basic block is
      # added — both paths go through nginx.
      # --------------------------------------------------------------------------
      services.nginx.enable = lib.mkIf (
        cfg.dashboard.enable && (cfg.dashboard.domain != null || cfg.dashboard.listenAddress != "127.0.0.1")
      ) true;

      services.nginx.virtualHosts = lib.mkMerge [
        (lib.mkIf (cfg.dashboard.enable && cfg.dashboard.domain != null) (
          nixlabLib.mkNginxVirtualHost {
            inherit (cfg.dashboard) domain enableSSL;
            listenAddress = "127.0.0.1";
            port = dashboardInternalPort;
            extraConfig =
              ''
                proxy_set_header Host 127.0.0.1:${toString dashboardInternalPort};
              ''
              + lib.optionalString cfg.dashboard.basicAuth.enable ''
                auth_basic "Hermes Dashboard";
                auth_basic_user_file ${cfg.dashboard.basicAuth.htpasswdFile};
              '';
          }
        ))
        (lib.mkIf (cfg.dashboard.enable && cfg.dashboard.domain == null && cfg.dashboard.listenAddress != "127.0.0.1") {
          "hermes-dashboard-lan" = {
            listen = [
              {
                addr = cfg.dashboard.listenAddress;
                port = cfg.dashboard.port;
              }
            ];
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString dashboardInternalPort}";
              extraConfig =
                ''
                  # Deliberately NOT forwarding the original Host header ($host) —
                  # hermes-agent's dashboard checks Host against the address it's
                  # bound to internally, not whatever hostname/IP the browser used
                  # to reach nginx.
                  proxy_set_header Host              127.0.0.1:${toString dashboardInternalPort};
                  proxy_set_header X-Real-IP         $remote_addr;
                  proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
                ''
                + lib.optionalString cfg.dashboard.basicAuth.enable ''
                  auth_basic "Hermes Dashboard";
                  auth_basic_user_file ${cfg.dashboard.basicAuth.htpasswdFile};
                '';
            };
          };
        })
      ];

      # --------------------------------------------------------------------------
      # FIREWALL
      # --------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts =
        lib.mkIf (cfg.dashboard.enable && cfg.dashboard.openFirewall)
        (nixlabLib.mkFirewallPorts {
          inherit (cfg.dashboard) domain listenAddress;
          servicePort = cfg.dashboard.port;
          extraPorts = [];
        });
    };
  };
}
