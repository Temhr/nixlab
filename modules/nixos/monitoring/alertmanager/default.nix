{...}: {
  flake.nixosModules.servc--alertmanager-nixlab = {
    config,
    lib,
    pkgs,
    nixlabLib,
    ...
  }: let
    cfg = config.services.alertmanager-nixlab;

    # ── Submodule types ────────────────────────────────────────────────────────

    # A single child route inside the routing tree.
    routeSubmodule = lib.types.submodule {
      options = {
        receiver = lib.mkOption {
          type = lib.types.str;
          description = "Name of the receiver this route delivers to.";
        };
        matchers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["severity=\"critical\"" "team=\"ops\""];
          description = ''
            List of label matchers (UTF-8 format) that must all match for
            this route to be selected.
          '';
        };
        groupBy = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["alertname" "cluster"];
          description = "Labels to group alerts by on this route.";
        };
        groupWait = lib.mkOption {
          type = lib.types.str;
          default = "30s";
          description = "How long to wait before sending an initial notification for a new group.";
        };
        groupInterval = lib.mkOption {
          type = lib.types.str;
          default = "5m";
          description = "How long to wait before sending a notification about new alerts added to an existing group.";
        };
        repeatInterval = lib.mkOption {
          type = lib.types.str;
          default = "4h";
          description = "How long to wait before re-sending an already-sent notification.";
        };
        continue = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "If true, continue matching subsequent sibling routes after this one matches.";
        };
        muteTimeIntervals = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["weekends" "business-hours"];
          description = "Named time intervals during which notifications for this route are muted.";
        };
      };
    };

    # A single inhibition rule.
    inhibitRuleSubmodule = lib.types.submodule {
      options = {
        sourceMatchers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["severity=\"critical\""];
          description = "Matchers for the source (suppressing) alert.";
        };
        targetMatchers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["severity=\"warning\""];
          description = "Matchers for the target (suppressed) alert.";
        };
        equal = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["alertname" "instance"];
          description = ''
            Labels that must have identical values on both source and target
            for the inhibition to apply. An empty list means the rule fires
            globally — usually not what you want.
          '';
        };
      };
    };

    # ── Config assembly helpers ────────────────────────────────────────────────

    mkRoute = r:
      {
        receiver = r.receiver;
        group_wait = r.groupWait;
        group_interval = r.groupInterval;
        repeat_interval = r.repeatInterval;
        continue = r.continue;
      }
      // lib.optionalAttrs (r.matchers != []) {matchers = r.matchers;}
      // lib.optionalAttrs (r.groupBy != []) {group_by = r.groupBy;}
      // lib.optionalAttrs (r.muteTimeIntervals != []) {
        mute_time_intervals = r.muteTimeIntervals;
      };

    mkInhibitRule = r:
      lib.optionalAttrs (r.sourceMatchers != []) {source_matchers = r.sourceMatchers;}
      // lib.optionalAttrs (r.targetMatchers != []) {target_matchers = r.targetMatchers;}
      // lib.optionalAttrs (r.equal != []) {equal = r.equal;};

    # Assembled alertmanager configuration attrset, merged with any extraConfig.
    amConfig =
      lib.recursiveUpdate {
        global =
          {resolve_timeout = cfg.global.resolveTimeout;}
          // lib.optionalAttrs (cfg.global.smtpFrom != null) {smtp_from = cfg.global.smtpFrom;}
          // lib.optionalAttrs (cfg.global.smtpSmarthost != null) {smtp_smarthost = cfg.global.smtpSmarthost;}
          // lib.optionalAttrs (cfg.global.smtpAuthUsername != null) {smtp_auth_username = cfg.global.smtpAuthUsername;}
          // lib.optionalAttrs (cfg.global.smtpRequireTLS != null) {smtp_require_tls = cfg.global.smtpRequireTLS;}
          // lib.optionalAttrs (cfg.global.slackApiUrl != null) {slack_api_url = cfg.global.slackApiUrl;}
          // lib.optionalAttrs (cfg.global.pagerdutyUrl != null) {pagerduty_url = cfg.global.pagerdutyUrl;};

        route =
          {
            receiver = cfg.defaultReceiver;
            group_by = cfg.route.groupBy;
            group_wait = cfg.route.groupWait;
            group_interval = cfg.route.groupInterval;
            repeat_interval = cfg.route.repeatInterval;
          }
          // lib.optionalAttrs (cfg.route.routes != []) {
            routes = map mkRoute cfg.route.routes;
          };

        receivers = cfg.receivers;
        inhibit_rules = map mkInhibitRule cfg.inhibitRules;

        time_intervals = cfg.timeIntervals;
      }
      cfg.extraConfig;
  in {
    # ============================================================================
    # OPTIONS - Define what can be configured
    # ============================================================================
    options = {
      services.alertmanager-nixlab = {
        enable = lib.mkEnableOption "Prometheus Alertmanager";

        port = lib.mkOption {
          type = lib.types.port;
          default = 9093;
          description = "Port for Alertmanager to listen on";
        };

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
        };

        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "alertmanager.example.com";
          description = "Domain name for nginx reverse proxy (optional)";
        };

        enableSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HTTPS with Let's Encrypt (requires domain)";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.prometheus-alertmanager;
          defaultText = lib.literalExpression "pkgs.prometheus-alertmanager";
          description = "The Alertmanager package to use";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open firewall ports";
        };

        extraUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["alice"];
          description = "Extra users to add to the alertmanager group";
        };

        # OPTIONAL: Validate config with amtool at build time (default: true).
        # Must be set to false when the config references $ENV_VAR secrets that
        # are not visible inside the Nix build sandbox.
        checkConfig = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Validate the generated configuration with `amtool check-config`
            at build time. Set to false when receivers reference $ENV_VAR
            secrets injected via the sops module — the sandbox cannot read
            the decrypted secrets file.
          '';
        };

        # Path to a KEY=VALUE environment file injected into the Alertmanager
        # process at startup. Populated by the companion nsops--alertmanager
        # module; set manually if you manage secrets another way.
        # Alertmanager expands $VAR references in the config YAML at startup,
        # so secrets never need to appear in the Nix store.
        environmentFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Path to a file containing KEY=VALUE pairs injected into the
            Alertmanager process environment. Intended to be set by the
            companion nsops--alertmanager module via sops-nix.

            When set, use $KEY references in receiver configs to keep secrets
            out of the store, and set checkConfig = false.
          '';
        };

        # ── HA cluster peering ─────────────────────────────────────────────────
        clusterPeers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["alertmanager-2.example.com" "alertmanager-3.example.com"];
          description = ''
            Addresses of other Alertmanager instances to peer with for HA.
            Port ${toString 9094} (clusterPort) is used automatically.
          '';
        };

        clusterPort = lib.mkOption {
          type = lib.types.port;
          default = 9094;
          description = "Port for Alertmanager cluster gossip communication.";
        };

        # ── Global defaults ────────────────────────────────────────────────────
        global = {
          resolveTimeout = lib.mkOption {
            type = lib.types.str;
            default = "5m";
            description = "How long to wait before declaring an alert resolved if it stops firing.";
          };

          smtpFrom = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "alertmanager@example.com";
            description = "Default SMTP From address.";
          };

          smtpSmarthost = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "smtp.example.com:587";
            description = "SMTP relay host:port.";
          };

          smtpAuthUsername = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "SMTP authentication username.";
          };

          smtpRequireTLS = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Require STARTTLS for SMTP connections. Null uses the alertmanager default (true).";
          };

          slackApiUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Global Slack incoming webhook URL. Use a $ENV_VAR reference here
              combined with environmentFile to keep the URL out of the store.
            '';
          };

          pagerdutyUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "PagerDuty API URL override (null = upstream default).";
          };
        };

        # ── Routing tree ───────────────────────────────────────────────────────
        defaultReceiver = lib.mkOption {
          type = lib.types.str;
          default = "null";
          description = ''
            Receiver that catches all alerts not matched by a child route.
            Defaults to "null" (drop) so notification destinations are
            explicitly opted into.
          '';
        };

        route = {
          groupBy = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = ["alertname" "instance"];
            description = "Labels to group alerts by at the root of the routing tree.";
          };

          groupWait = lib.mkOption {
            type = lib.types.str;
            default = "30s";
            description = "How long to wait before sending the first notification for a new group.";
          };

          groupInterval = lib.mkOption {
            type = lib.types.str;
            default = "5m";
            description = "How long to wait before notifying about new alerts added to an existing group.";
          };

          repeatInterval = lib.mkOption {
            type = lib.types.str;
            default = "4h";
            description = "How long to wait before re-sending an already-sent notification.";
          };

          routes = lib.mkOption {
            type = lib.types.listOf routeSubmodule;
            default = [];
            description = ''
              Child routes evaluated in order. The first match wins unless
              continue = true is set on the matched route.
            '';
            example = [
              {
                matchers = ["severity=\"critical\""];
                receiver = "pagerduty-critical";
                groupWait = "10s";
                repeatInterval = "1h";
              }
              {
                matchers = ["severity=\"warning\""];
                receiver = "slack-warnings";
              }
            ];
          };
        };

        # ── Receivers ─────────────────────────────────────────────────────────
        receivers = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [{name = "null";}];
          description = ''
            Alertmanager receiver list. Each entry must have a "name" field.
            Integration configs are specified as <type>_configs lists on the
            same attrset.

            Reference secrets as $ENV_VAR strings; inject values at runtime
            via the companion nsops--alertmanager sops module.

            See https://prometheus.io/docs/alerting/latest/configuration/#receiver
          '';
          example = [
            {name = "null";}
            {
              name = "slack-warnings";
              slack_configs = [
                {
                  api_url = "$SLACK_WEBHOOK_URL";
                  channel = "#alerts";
                  send_resolved = true;
                }
              ];
            }
            {
              name = "pagerduty-critical";
              pagerduty_configs = [
                {
                  routing_key = "$PAGERDUTY_ROUTING_KEY";
                  send_resolved = true;
                }
              ];
            }
            {
              name = "ntfy";
              webhook_configs = [
                {
                  url = "http://localhost:2586/alerts";
                  send_resolved = true;
                }
              ];
            }
          ];
        };

        # ── Inhibition rules ───────────────────────────────────────────────────
        inhibitRules = lib.mkOption {
          type = lib.types.listOf inhibitRuleSubmodule;
          default = [
            {
              sourceMatchers = ["severity=\"critical\""];
              targetMatchers = ["severity=\"warning\""];
              equal = ["alertname" "instance"];
            }
          ];
          description = ''
            Inhibition rules that suppress target alerts when source alerts
            are firing. The default suppresses warnings when a critical fires
            for the same alertname + instance.
          '';
        };

        # ── Time intervals (mute windows) ──────────────────────────────────────
        timeIntervals = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [];
          description = ''
            Named time intervals used by routes to mute notifications during
            specific periods (weekends, on-call hours, maintenance windows).
            See https://prometheus.io/docs/alerting/latest/configuration/#time_interval
          '';
          example = [
            {
              name = "weekends";
              time_intervals = [{weekdays = ["saturday" "sunday"];}];
            }
            {
              name = "business-hours";
              time_intervals = [
                {
                  times = [
                    {
                      start_time = "08:00";
                      end_time = "18:00";
                    }
                  ];
                  weekdays = ["monday:friday"];
                }
              ];
            }
          ];
        };

        # ── Escape hatch ───────────────────────────────────────────────────────
        extraConfig = lib.mkOption {
          type = lib.types.attrs;
          default = {};
          description = ''
            Raw attrset deep-merged into the generated Alertmanager config.
            Keys here take precedence over the structured options above.
            Use for fields not yet covered by this module.
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
          moduleName = "services.alertmanager-nixlab";
        })
        {
          # Every receiver name referenced by a route must be defined.
          assertion = let
            defined = map (r: r.name) cfg.receivers;
            referenced = [cfg.defaultReceiver] ++ map (r: r.receiver) cfg.route.routes;
            missing = builtins.filter (r: !(builtins.elem r defined)) referenced;
          in
            missing == [];
          message = let
            defined = map (r: r.name) cfg.receivers;
            referenced = [cfg.defaultReceiver] ++ map (r: r.receiver) cfg.route.routes;
            missing = builtins.filter (r: !(builtins.elem r defined)) referenced;
          in ''
            services.alertmanager-nixlab: the following receiver names are
            referenced in routes but not defined in cfg.receivers:
              ${lib.concatStringsSep "\n  " missing}
          '';
        }
        {
          # Prevent a confusing build-time failure when secrets aren't
          # visible to the Nix sandbox.
          assertion = !(cfg.environmentFile != null && cfg.checkConfig);
          message = ''
            services.alertmanager-nixlab: environmentFile is set but
            checkConfig is still true. The Nix sandbox cannot read the
            secrets file so amtool check-config will fail at build time.
            Set services.alertmanager-nixlab.checkConfig = false.
          '';
        }
        {
          assertion = cfg.clusterPeers == [] || cfg.openFirewall;
          message = ''
            services.alertmanager-nixlab: clusterPeers is set but
            openFirewall is false. The cluster gossip port
            (${toString cfg.clusterPort}) must be reachable from peers.
            Set openFirewall = true or open the port manually.
          '';
        }
      ];

      # ----------------------------------------------------------------------------
      # UPSTREAM MODULE - Delegate to the NixOS alertmanager module.
      # It handles DynamicUser, StateDirectory, amtool check-config, and
      # envsubst secret expansion — we don't reimplement any of that.
      # ----------------------------------------------------------------------------
      services.prometheus.alertmanager = {
        enable = true;
        package = cfg.package;
        port = cfg.port;
        # NOTE: the upstream services.prometheus.alertmanager module appends
        # ":<port>" to this value itself — do NOT include the port here, or
        # you get a malformed "0.0.0.0:9093:9093" listen address and the
        # service fails to start (start-limit-hit after repeated crashes).
        listenAddress = cfg.listenAddress;
        checkConfig = cfg.checkConfig;

        webExternalUrl =
          if cfg.domain != null
          then "${
            if cfg.enableSSL
            then "https"
            else "http"
          }://${cfg.domain}/"
          else "http://${cfg.listenAddress}:${toString cfg.port}/";

        clusterPeers = cfg.clusterPeers;

        extraFlags = lib.optionals (cfg.clusterPeers != []) [
          "--cluster.listen-address=0.0.0.0:${toString cfg.clusterPort}"
        ];

        configuration = amConfig;
      };

      # Inject the sops-decrypted environment file into the upstream unit.
      # mkAfter ensures we append rather than clobber the unit's own settings.
      systemd.services.alertmanager = lib.mkIf (cfg.environmentFile != null) {
        serviceConfig.EnvironmentFiles = lib.mkAfter [cfg.environmentFile];
      };

      # ----------------------------------------------------------------------------
      # GROUP MEMBERSHIP
      # ----------------------------------------------------------------------------
      users.users = lib.mkMerge (
        lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
        (map (u: {${u} = {extraGroups = ["alertmanager"];};})
          ([config.nixlab.mainUser] ++ cfg.extraUsers))
      );

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
      # FIREWALL - Open necessary ports if requested
      # ----------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts =
        lib.mkIf cfg.openFirewall
        (nixlabLib.mkFirewallPorts {
            inherit (cfg) domain listenAddress;
            servicePort = cfg.port;
          }
          ++ lib.optionals (cfg.clusterPeers != []) [cfg.clusterPort]);
    };
  };
}
