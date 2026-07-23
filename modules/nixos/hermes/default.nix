{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.servc--hermes-nixlab = {
    config,
    lib,
    nixlabLib,
    ...
  }: let
    cfg = config.services.nixlab-hermes;

    hermesStateDir = config.services.hermes-agent.stateDir;

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
        baseUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:11434/v1";
          description = ''
            OpenAI-compatible base URL hermes-agent uses to reach the model
            backend. For a local Ollama, this is Ollama's own /v1 endpoint —
            NOT a separate "ollama" integration. Ollama serves an
            OpenAI-compatible API at this path; that's the only wiring
            hermes-agent needs (there is no dedicated OLLAMA_API_BASE-style
            hook — settings.model.base_url is the single mechanism).
          '';
        };

        default = lib.mkOption {
          type = lib.types.str;
          default = "gemma4:e4b";
          description = "Model name hermes-agent requests from the backend — must exactly match a model already pulled by Ollama (see services.ollama-stack.models).";
        };
      };

      mcpServers = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = {};
        example = {
          filesystem = {
            url = "http://127.0.0.1:8210";
          };
        };
        description = ''
          MCP server definitions passed through to services.hermes-agent.mcpServers.
          MUST be an attrset keyed by server name (matches upstream's
          attrsOf-submodule shape) — NOT a list. A list here will fail
          evaluation.
        '';
      };

      messagingEnvFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Path to a dotenv-format file with LLM/messaging secrets, merged
          into hermes-agent's environment via environmentFiles. This is
          the ONLY place messaging credentials live — including Matrix's
          MATRIX_HOMESERVER / MATRIX_USER_ID / MATRIX_PASSWORD /
          MATRIX_ALLOWED_USERS. See hermes-agent's own Matrix setup docs
          for the full set of recognized keys.
        '';
      };

      extraUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["alice"];
        description = "Extra users to add to the hermes-agent group, alongside nixlab.mainUser.";
      };

      matrix = {
        enable = lib.mkEnableOption ''
          Matrix as a messaging channel for hermes-agent. This is a thin
          toggle only: it pulls in the "matrix" dependency group and orders
          hermes-agent after the homeserver + account-registration units.
          ALL actual credentials (MATRIX_HOMESERVER, MATRIX_USER_ID,
          MATRIX_PASSWORD, MATRIX_ALLOWED_USERS) come from messagingEnvFile —
          hermes-agent logs in itself at startup (password-login, per its
          own docs); there is no separate token-minting step and no
          settings.yaml key that "enables" Matrix. MATRIX_ALLOWED_USERS is
          mandatory in practice: without it hermes-agent denies every user
          as a safety default.
        '';
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
          assertion =
            cfg.dashboard.enable
            && cfg.dashboard.listenAddress != "127.0.0.1"
            -> (cfg.dashboard.basicAuth.enable || cfg.dashboard.allowUnauthenticatedLan);
          message = ''
            services.nixlab-hermes.dashboard.listenAddress is set to a non-loopback
            address, but neither basicAuth.enable nor allowUnauthenticatedLan is set.
          '';
        }
        {
          assertion = cfg.dashboard.basicAuth.enable -> cfg.dashboard.basicAuth.htpasswdFile != null;
          message = "services.nixlab-hermes.dashboard.basicAuth.enable requires htpasswdFile to be set";
        }
        {
          assertion = cfg.matrix.enable -> cfg.messagingEnvFile != null;
          message = ''
            services.nixlab-hermes.matrix.enable requires messagingEnvFile to be
            set and to contain at least MATRIX_HOMESERVER, MATRIX_USER_ID,
            MATRIX_PASSWORD, and MATRIX_ALLOWED_USERS — Hermes logs into
            Matrix itself at startup using these, there is no separate
            login/token-minting step in this module.
          '';
        }
      ];

      # --------------------------------------------------------------------------
      # HERMES AGENT SERVICE
      # --------------------------------------------------------------------------
      systemd.services.hermes-agent.after =
        lib.optionals cfg.matrix.enable ["continuwuity.service" "matrix-nixlab-init-users.service"];
      systemd.services.hermes-agent.wants =
        lib.optionals cfg.matrix.enable ["continuwuity.service" "matrix-nixlab-init-users.service"];

      services.hermes-agent = {
        enable = true;
        environment = {
          OPENAI_API_KEY = "not-needed-for-local-ollama";
        };
        extraDependencyGroups = lib.optionals cfg.matrix.enable ["matrix"];

        settings = {
          model = {
            provider = "custom";
            base_url = cfg.model.baseUrl;
            default = cfg.model.default;
          };
          approvals.mode = "smart";
          approvals.cron_mode = "deny";
          delegation.orchestrator_enabled = true;
          delegation.max_spawn_depth = 2;
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
      # DASHBOARD - web UI, opt-in via dashboard.enable
      # --------------------------------------------------------------------------
      systemd.services.hermes-dashboard = lib.mkIf cfg.dashboard.enable {
        description = "Hermes web UI dashboard";
        after = ["hermes-agent.service"];
        wants = ["hermes-agent.service"];
        wantedBy = ["multi-user.target"];

        serviceConfig =
          nixlabLib.mkServiceHardening {
            writablePaths = [hermesStateDir];
            allowJIT = true;
          }
          // {
            Type = "simple";
            User = config.services.hermes-agent.user;
            Group = config.services.hermes-agent.group;
            ExecStart = "${config.services.hermes-agent.package}/bin/hermes dashboard --host 127.0.0.1 --port ${toString dashboardInternalPort} --skip-build --no-open --tui";
            Restart = "on-failure";
            RestartSec = 5;
          };
      };

      # --------------------------------------------------------------------------
      # NGINX — required for ANY off-loopback dashboard access, auth or not.
      # --------------------------------------------------------------------------
      services.nginx.enable =
        lib.mkIf (
          cfg.dashboard.enable && (cfg.dashboard.domain != null || cfg.dashboard.listenAddress != "127.0.0.1")
        )
        true;

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
              proxyWebsockets = true;
              extraConfig =
                ''
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
