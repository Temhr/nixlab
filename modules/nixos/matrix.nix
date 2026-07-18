{...}: {
  flake.nixosModules.servc--matrix-nixlab = {
    config,
    lib,
    nixlabLib,
    pkgs,
    ...
  }: let
    cfg = config.services.matrix-nixlab;
  in {
    imports = [
      #self.nixosModules.systm--ports-matrix
    ];
    # ============================================================================
    # OPTIONS - Define what can be configured
    # ============================================================================
    options = {
      services.matrix-nixlab = {
        # REQUIRED: Enable the service
        enable = lib.mkEnableOption "self-hosted Matrix homeserver (Continuwuity), for use standalone or as a messaging backend for agent services like Hermes";

        # OPTIONAL: The Matrix server_name — the account/federation identity suffix
        # (accounts are @user:server_name). Defaults to a per-host name derived from
        # networking.hostName, so deploying this module on multiple machines gives
        # each one a distinct identity automatically with zero hand-coding.
        #
        # WARNING: cannot be changed later without recreating every account on that
        # host's homeserver — the database is initialized against this value on
        # first start and the server will refuse to start if it later disagrees.
        # If you rename this host later, this default silently changes too; pin
        # an explicit string instead if you want the identity to survive a rename.
        serverName = lib.mkOption {
          type = lib.types.str;
          default = "matrix-nix.internal";
          defaultText = lib.literalExpression ''"matrix-nix.internal"'';
          example = "matrix.yourdomain.tld";
          description = "Federation/account identity suffix. See warning above before changing on a live server.";
        };

        # OPTIONAL: Port Continuwuity listens on (default: 6167)
        port = lib.mkOption {
          type = lib.types.port;
          default = 6167;
          description = "Port for Continuwuity to listen on";
        };

        # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
        # Use 0.0.0.0 or your LAN interface address for reachability from other
        # devices (e.g. Element on your phone). Keep 127.0.0.1 while a client
        # only needs to reach this from the same host (e.g. Hermes colocated here).
        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "IP address to bind to (use 0.0.0.0 for LAN access)";
        };

        # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
        # Only needed if exposing this beyond your LAN/VPN. No domain registrar
        # needed for LAN-only use — use a Pi-hole, router DNS, or .internal name.
        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "matrix.example.com";
          description = "Domain name for nginx reverse proxy (optional)";
        };

        # OPTIONAL: Enable HTTPS via Let's Encrypt (default: false)
        # Only works with publicly resolvable domains. Do not enable for
        # LAN-only/.internal names.
        enableSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HTTPS with Let's Encrypt (requires a publicly resolvable domain)";
        };

        # OPTIONAL: Allow new account registration (default: false)
        # Flip true only transiently to create an account (bot or otherwise),
        # using the token Continuwuity prints to its own journal on first start
        # (or registrationTokenFile below, once you have a persistent one) —
        # then set back to false. Leaving this true indefinitely leaves the
        # registration endpoint open to anyone with the token.
        allowRegistration = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Allow account registration. Flip transiently, do not leave enabled.";
        };

        # OPTIONAL: sops-nix path to a persistent registration token (default: null)
        # Continuwuity reads this file once at startup (not re-read on config
        # reload — a restart is required to pick up a new token). Without this
        # set, Continuwuity auto-generates a one-time token per fresh database
        # and logs it to the journal instead — fine for a single bootstrap
        # account, but set this if you'll be registering more accounts later.
        # In your host config:
        #   registrationTokenFile = config.sops.secrets.MATRIX_REGISTRATION_TOKEN.path;
        registrationTokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = "/run/secrets/MATRIX_REGISTRATION_TOKEN";
          description = "Path to sops-decrypted registration token (bare value, no KEY= prefix).";
        };

        # OPTIONAL: Open firewall ports automatically (default: false)
        # Off by default, unlike most other services in this repo — a Matrix
        # homeserver is meaningfully different from e.g. a dashboard: opening
        # it exposes account registration and federation surface. Opt in
        # deliberately once you've decided this should be reachable beyond
        # the host it runs on.
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Open firewall ports. Off by default — opt in deliberately.";
        };

        # OPTIONAL: One-shot registration of fixed accounts at boot (default: disabled)
        # Requires registrationTokenFile to be set — this reuses that token to
        # register the accounts below, then the unit exits. Runs on every boot,
        # but registration is idempotent server-side (M_USER_IN_USE on repeat),
        # so this is safe to leave enabled rather than flipping it on/off.
        initUsers = {
          enable = lib.mkEnableOption "one-shot registration of the accounts in initUsers.accounts at boot";

          accounts = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                username = lib.mkOption {
                  type = lib.types.str;
                  description = "Localpart to register, e.g. \"hermes\" for @hermes:server_name.";
                };
                passwordFile = lib.mkOption {
                  type = lib.types.path;
                  description = "Path to a file containing the bare password (no KEY= prefix), e.g. a sops secret path.";
                };
              };
            });
            default = [];
            example = lib.literalExpression ''
              [
                {
                  username = "hermes-bot";
                  passwordFile = config.sops.secrets.MATRIX_HERMES-BOT_PASSWORD.path;
                }
                {
                  username = "temhr";
                  passwordFile = config.sops.secrets.MATRIX_TEMHR_PASSWORD.path;
                }
              ]
            '';
            description = "Accounts to register on boot via the registration-token endpoint.";
          };
        };
      };
    };

    # ============================================================================
    # CONFIG - What happens when the service is enabled
    # ============================================================================
    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !cfg.initUsers.enable || cfg.registrationTokenFile != null;
          message = "services.matrix-nixlab.initUsers.enable requires registrationTokenFile to be set.";
        }
      ];

      # Static group so the DynamicUser continuwuity process can read the
      # sops-owned registration token. DynamicUser only gets a name binding
      # at runtime, so root can't chown the secret to it at activation —
      # grant access via group membership instead.
      users.groups.matrix-nixlab-secrets = {};

      systemd.services.continuwuity.serviceConfig.SupplementaryGroups =
        lib.mkIf (cfg.registrationTokenFile != null) ["matrix-nixlab-secrets"];

      services.matrix-continuwuity = {
        enable = true;
        settings.global =
          {
            server_name = cfg.serverName;
            port = [cfg.port];
            address = [cfg.listenAddress];
            # Registration must be enabled for the token endpoint to work at all;
            # if initUsers is on, force it regardless of the allowRegistration
            # setting above rather than requiring the user to remember to flip both.
            allow_registration = cfg.allowRegistration || cfg.initUsers.enable;
          }
          // lib.optionalAttrs (cfg.registrationTokenFile != null) {
            registration_token_file = cfg.registrationTokenFile;
          };
      };

      # --------------------------------------------------------------------------
      # INIT USERS - one-shot registration, opt-in via initUsers.enable
      # --------------------------------------------------------------------------
      systemd.services.matrix-nixlab-init-users = lib.mkIf cfg.initUsers.enable {
        description = "Register fixed matrix-nixlab accounts on boot, handling Continuwuity's firstrun bootstrap automatically";
        after = ["continuwuity.service"];
        wants = ["continuwuity.service"];
        wantedBy = ["multi-user.target"];
        path = [pkgs.curl pkgs.jq pkgs.systemd pkgs.gnugrep pkgs.gawk];
        serviceConfig = {
          Type = "oneshot";
          LoadCredential = map (a: "${a.username}_pw:${a.passwordFile}") cfg.initUsers.accounts;
        };
        script = let
          base = "http://${cfg.listenAddress}:${toString cfg.port}";
          accountsBlock =
            lib.concatMapStringsSep "\n" (a: ''
              pass=$(cat "$CREDENTIALS_DIRECTORY/${a.username}_pw")
              register_with_bootstrap_fallback "${a.username}" "$pass" || FAILURES=$((FAILURES + 1))
            '')
            cfg.initUsers.accounts;
        in ''
          set -eu
          STATIC_TOKEN=$(cat ${cfg.registrationTokenFile})
          FAILURES=0

          for i in $(seq 1 30); do
            curl -sS -o /dev/null "${base}/_matrix/client/versions" && break
            sleep 1
          done

          # Attempts registration for one user with one token via the two-step
          # UIA flow. Returns: 0 = success or already-exists, 1 = rejected
          # (caller may retry with a different token), 2 = other failure.
          try_register() {
            user="$1"; pass="$2"; token="$3"
            session=$(curl -sS -X POST "${base}/_matrix/client/v3/register" \
              -H 'Content-Type: application/json' \
              -d "{\"username\":\"$user\",\"password\":\"$pass\"}" \
              | jq -r '.session // empty')
            if [ -z "$session" ]; then
              echo "$user: could not obtain UIA session"
              return 2
            fi
            resp=$(curl -sS -w '\n%{http_code}' -X POST "${base}/_matrix/client/v3/register" \
              -H 'Content-Type: application/json' \
              -d "{\"username\":\"$user\",\"password\":\"$pass\",\"auth\":{\"type\":\"m.login.registration_token\",\"token\":\"$token\",\"session\":\"$session\"}}")
            code=$(echo "$resp" | tail -n1)
            body=$(echo "$resp" | sed '$d')
            case "$code" in
              200) echo "$user: registered"; return 0 ;;
              400) echo "$user: already exists (HTTP 400)"; return 0 ;;
              401) echo "$user: rejected (HTTP 401) — $body"; return 1 ;;
              *) echo "$user: unexpected HTTP $code — $body"; return 2 ;;
            esac
          }

          # Tries the static token first; on rejection, scrapes the current
          # continuwuity invocation's freshly-printed firstrun bootstrap token
          # from the journal and retries once. Only ever needed for the very
          # first account registered against a fresh database.
          register_with_bootstrap_fallback() {
            user="$1"; pass="$2"
            status=0
            try_register "$user" "$pass" "$STATIC_TOKEN" || status=$?

            if [ "$status" -eq 0 ]; then
              return 0
            fi
            if [ "$status" -ne 1 ]; then
              return 1
            fi

            echo "$user: static token rejected, checking for firstrun bootstrap token"
            mainpid=$(systemctl show -p MainPID --value continuwuity.service)
            boot_token=""
            for i in $(seq 1 10); do
              boot_token=$(journalctl "_PID=$mainpid" --no-pager \
                | grep -o 'registration token [A-Za-z0-9]*' | tail -n1 | awk '{print $NF}')
              [ -n "$boot_token" ] && break
              sleep 0.5
            done

            if [ -z "$boot_token" ]; then
              echo "$user: no firstrun bootstrap token found in journal after waiting — giving up"
              return 1
            fi

            echo "$user: retrying with firstrun bootstrap token"
            try_register "$user" "$pass" "$boot_token"
          }

          ${accountsBlock}

          if [ "$FAILURES" -gt 0 ]; then
            echo "$FAILURES account(s) failed to register"
            exit 1
          fi
        '';
      };

      # --------------------------------------------------------------------------
      # NGINX REVERSE PROXY - Only configured when domain is set
      # --------------------------------------------------------------------------
      services.nginx.enable = lib.mkIf (cfg.domain != null) true;
      services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) (
        nixlabLib.mkNginxVirtualHost {
          inherit (cfg) domain enableSSL;
          listenAddress = "127.0.0.1";
          port = cfg.port;
        }
      );

      # --------------------------------------------------------------------------
      # FIREWALL - opt-in, see openFirewall description above
      # --------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts =
        lib.mkIf cfg.openFirewall
        (nixlabLib.mkFirewallPorts {
          inherit (cfg) domain listenAddress;
          servicePort = cfg.port;
        });
    };
  };
}
