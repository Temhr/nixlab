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
  in {
    imports = [
      inputs.hermes-agent.nixosModules.default
      self.nixosModules.systm--ports-hermes
    ];

    options.services.nixlab-hermes = {
      enable = lib.mkEnableOption "Hermes Agent (multi-agent supervisor/worker system)";

      modelProvider = lib.mkOption {
        type = lib.types.str;
        default = "custom";
      };
      modelBaseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:11434/v1";
      };
      modelDefault = lib.mkOption {
        type = lib.types.str;
        default = "gemma4:e4b";
      };

      ollamaBaseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:11434";
      };

      mcpServers = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = {};
      };

      # Renamed from telegramEnvFile — same option, more accurate name now
      # that Matrix is the actual channel.
      messagingEnvFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };

      extraUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };

      dashboard = {
        enable = lib.mkEnableOption "Hermes web UI dashboard";

        port = lib.mkOption {
          type = lib.types.port;
          default = 9119;
          description = "Port the dashboard listens on.";
        };

        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "hermes.example.com";
          description = "Domain name for nginx reverse proxy (optional).";
        };

        enableSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HTTPS with Let's Encrypt (requires a publicly resolvable domain).";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Open firewall ports. Off by default — opt in deliberately.";
        };
      };

      matrixLogin = {
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

    config = lib.mkIf cfg.enable {
      systemd.services.hermes-agent.after = [
        "continuwuity.service"
        "matrix-nixlab-init-users.service"
        "hermes-matrix-login.service"
      ];
      systemd.services.hermes-agent.wants = [
        "matrix-nixlab-init-users.service"
        "hermes-matrix-login.service"
      ];

      services.hermes-agent = {
        enable = true;

        # Confirmed real option — pulls the "matrix" pyproject extra into
        # the sealed venv, per the module source (uv-resolved, no PYTHONPATH
        # patching).
        extraDependencyGroups = ["matrix"];

        settings = {
          model = {
            provider = cfg.modelProvider;
            base_url = cfg.modelBaseUrl;
            default = cfg.modelDefault;
          };
          approvals.mode = "smart";
          approvals.cron_mode = "deny";
          delegation.orchestrator_enabled = true;
          delegation.max_spawn_depth = 2;
          # NOTE: unverified key path, same caveat as messaging.telegram.enabled
          # last time — grep the venv before trusting this.
          messaging.matrix.enabled = true;
        };

        environment = {
          OLLAMA_API_BASE = cfg.ollamaBaseUrl;
        };

        mcpServers = cfg.mcpServers;

        environmentFiles =
          lib.optionals (cfg.messagingEnvFile != null) [(toString cfg.messagingEnvFile)];
      };

      users.users = lib.mkMerge (
        lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
        (map (u: {${u} = {extraGroups = [config.services.hermes-agent.group];};})
          ([config.nixlab.mainUser] ++ cfg.extraUsers))
      );

      systemd.services.hermes-matrix-login = lib.mkIf cfg.matrixLogin.enable {
        description = "Log in as ${cfg.matrixLogin.username} and mint a fresh Matrix access token for hermes-agent";
        after = ["continuwuity.service" "matrix-nixlab-init-users.service" "network-online.target"];
        wants = ["continuwuity.service" "matrix-nixlab-init-users.service" "network-online.target"];
        wantedBy = ["multi-user.target"];
        path = [pkgs.curl pkgs.jq];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          LoadCredential = ["login_pw:${cfg.matrixLogin.passwordFile}"];
        };
        script = let
          base = cfg.matrixLogin.homeserverUrl;
          envFile = "/var/lib/hermes/.hermes/.env";
        in ''
          set -eu
          pass=$(cat "$CREDENTIALS_DIRECTORY/login_pw")

          for i in $(seq 1 30); do
            curl -sS -o /dev/null "${base}/_matrix/client/versions" && break
            sleep 1
          done

          resp=$(curl -sS -X POST "${base}/_matrix/client/v3/login" \
            -H 'Content-Type: application/json' \
            -d "{\"type\":\"m.login.password\",\"identifier\":{\"type\":\"m.id.user\",\"user\":\"${cfg.matrixLogin.username}\"},\"password\":\"$pass\",\"device_id\":\"${cfg.matrixLogin.deviceId}\",\"initial_device_display_name\":\"hermes-agent\"}")

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
          if [ -f "${envFile}" ]; then
            grep -v -E '^(MATRIX_ACCESS_TOKEN|MATRIX_USER_ID)=' "${envFile}" > "${envFile}.tmp"
          else
            : > "${envFile}.tmp"
          fi
          printf 'MATRIX_ACCESS_TOKEN=%s\nMATRIX_USER_ID=%s\n' "$token" "$user_id" >> "${envFile}.tmp"
          mv "${envFile}.tmp" "${envFile}"
          chown ${config.services.hermes-agent.user}:${config.services.hermes-agent.group} "${envFile}"
          chmod 0640 "${envFile}"
          echo "logged in as $user_id, updated ${envFile}"
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
        serviceConfig = {
          Type = "simple";
          User = config.services.hermes-agent.user;
          Group = config.services.hermes-agent.group;
          ExecStart = "${config.services.hermes-agent.package}/bin/hermes dashboard --host 127.0.0.1 --port ${toString cfg.dashboard.port} --skip-build --no-open";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      services.nginx.enable = lib.mkIf (cfg.dashboard.enable && cfg.dashboard.domain != null) true;
      services.nginx.virtualHosts = lib.mkIf (cfg.dashboard.enable && cfg.dashboard.domain != null) (
        nixlabLib.mkNginxVirtualHost {
          inherit (cfg.dashboard) domain enableSSL;
          listenAddress = "127.0.0.1";
          port = cfg.dashboard.port;
        }
      );

      networking.firewall.allowedTCPPorts =
        lib.mkIf (cfg.dashboard.enable && cfg.dashboard.openFirewall)
        [cfg.dashboard.port];
    };
  };
}
