{self, ...}: {
  flake.nixosModules.servc--loki-nixlab = {
    config,
    lib,
    pkgs,
    nixlabLib,
    ...
  }: let
    cfg = config.services.loki-nixlab;
  in {
    imports = [
      self.nixosModules.systm--ports-loki
    ];
    # ============================================================================
    # OPTIONS - Define what can be configured
    # ============================================================================
    options = {
      services.loki-nixlab = {
        # REQUIRED: Enable the service
        enable = lib.mkEnableOption "Loki log aggregation system";

        # OPTIONAL: Port to listen on (default: 3100)
        port = lib.mkOption {
          type = lib.types.port;
          default = 3100;
          description = "Port for Loki to listen on";
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
          example = "loki.example.com";
          description = "Domain name for nginx reverse proxy (optional)";
        };

        # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
        enableSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HTTPS with Let's Encrypt (requires domain)";
        };

        # OPTIONAL: Where to store Loki data (default: /var/lib/loki)
        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/loki";
          example = "/data/loki";
          description = "Directory for Loki data storage";
        };

        # OPTIONAL: Log retention period (default: 744h = 31 days)
        retention = lib.mkOption {
          type = lib.types.str;
          default = "744h";
          example = "2160h";
          description = "How long to retain log data (in hours)";
        };

        # OPTIONAL: Loki package to use (default: pkgs.grafana-loki)
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.grafana-loki;
          defaultText = lib.literalExpression "pkgs.grafana-loki";
          description = "The Loki package to use";
        };

        # OPTIONAL: Alloy package to use (default: pkgs.grafana-alloy)
        alloyPackage = lib.mkOption {
          type = lib.types.package;
          default = pkgs.grafana-alloy;
          defaultText = lib.literalExpression "pkgs.grafana-alloy";
          description = "The Grafana Alloy package to use";
        };

        # OPTIONAL: Auto-open firewall ports (default: true)
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open firewall ports";
        };

        # OPTIONAL: Enable Alloy for local log collection (default: true)
        enableAlloy = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Grafana Alloy to collect system logs";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "loki";
          description = "User to run Loki as";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "loki";
          description = "Group to run Loki as";
        };

        uid = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Pinned uid for the loki user (null = allocate dynamically).";
        };

        gid = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Pinned gid for the loki group.";
        };

        # OPTIONAL: allow opting out of the mainUser group membership
        # without coupling to a specific external option name
        extraUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["alice"];
          description = "Extra users to add to the groups";
        };

        ruler = {
          enable = lib.mkEnableOption "Loki ruler (LogQL alert rules evaluated inside Loki)";

          alertmanagerUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "http://127.0.0.1:9093";
            description = "Alertmanager that receives the ruler's alerts. Required when the ruler is enabled.";
          };

          groups = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [];
            description = "Rule groups (name, interval, rules) written to the ruler's local rule directory.";
          };
        };

        # Maintenance monitoring options
        maintenance = {
          enable = lib.mkEnableOption "maintenance task logging integration";

          logPath = lib.mkOption {
            type = lib.types.str;
            default = "/var/log/maintenance.jsonl";
            description = "Path to the maintenance log (JSON lines). Must NOT end in .log or it will also be picked up by the /var/log/*.log pipeline.";
          };
        };

        grpcPort = lib.mkOption {
          type = lib.types.port;
          default = 9096;
          description = "gRPC port for Loki internal communication. Only relevant for multi-instance deployments.";
        };

        openGrpcFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Open the gRPC port in the firewall. Only needed for multi-instance Loki deployments.";
        };

        alloyPort = lib.mkOption {
          type = lib.types.port;
          default = 12345;
          description = "Port for Alloy's HTTP server (UI, /metrics). Bound to loopback.";
        };
      };
    };

    # ============================================================================
    # CONFIG - What happens when the service is enabled
    # ============================================================================
    config = lib.mkIf cfg.enable (lib.mkMerge [
      {
        # ============================================================================
        # ASSERTIONS - Catch invalid option combinations at eval time
        # ============================================================================
        assertions = [
          (nixlabLib.mkSslAssertion {
            inherit (cfg) enableSSL domain;
            moduleName = "services.loki-nixlab";
          })
          {
            assertion = !(cfg.maintenance.enable && lib.hasSuffix ".log" cfg.maintenance.logPath);
            message = "services.loki-nixlab.maintenance.logPath must not end in .log (it would also be tailed by the /var/log/*.log pipeline and ingested twice).";
          }
          {
            assertion = !cfg.ruler.enable || cfg.ruler.alertmanagerUrl != null;
            message = "services.loki-nixlab.ruler.enable needs services.loki-nixlab.ruler.alertmanagerUrl.";
          }
        ];

        # ----------------------------------------------------------------------------
        # DIRECTORY SETUP - Create necessary directories with proper permissions
        # ----------------------------------------------------------------------------
        systemd.tmpfiles.rules = [
          "d ${cfg.dataDir} 0770 ${cfg.user} ${cfg.group} -"
          "d ${cfg.dataDir}/chunks 0770 ${cfg.user} ${cfg.group} -"
          "d ${cfg.dataDir}/index 0770 ${cfg.user} ${cfg.group} -"
          "d ${cfg.dataDir}/wal 0770 ${cfg.user} ${cfg.group} -"
        ];

        # ----------------------------------------------------------------------------
        # USER SETUP - Create dedicated system users
        # ----------------------------------------------------------------------------
        users.users = lib.mkMerge (
          [
            {
              ${cfg.user} = {
                isSystemUser = true;
                group = cfg.group;
                home = cfg.dataDir;
                description = "Loki service user";
                uid = cfg.uid;
              };
            }
          ]
          ++ lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
          (map (u: {${u} = {extraGroups = [cfg.group];};})
            ([config.nixlab.mainUser] ++ cfg.extraUsers))
        );

        users.groups.${cfg.group} = {};

        # ----------------------------------------------------------------------------
        # PERMISSIONS - fix ownership every boot, after dataDir is actually mounted
        #
        # tmpfiles' "d" rules above only create these directories if missing — they
        # never fix ownership on an already-existing one, and a separate-mount
        # dataDir can race tmpfiles at boot before the mount exists. This oneshot
        # waits for the real mount and then recursively chowns, fixing both that
        # race and any UID/GID drift from a rebuild.
        # ----------------------------------------------------------------------------
        systemd.services.loki-permissions = nixlabLib.mkDataDirPermissionsService {
          inherit pkgs;
          dataDir = cfg.dataDir;
          user = cfg.user;
          group = cfg.group;
          requiredBy = ["loki.service"];
        };

        # ----------------------------------------------------------------------------
        # LOKI SERVICE - Configure the systemd service
        # ----------------------------------------------------------------------------
        systemd.services.loki = {
          description = "Loki Log Aggregation System";
          wantedBy = ["multi-user.target"];
          after = ["network.target" "loki-permissions.service" "time-sync.target"];
          wants = ["time-sync.target"];

          serviceConfig =
            nixlabLib.mkServiceHardening {
              writablePaths = [cfg.dataDir];
              extraHardening = true;
            }
            // {
              Type = "simple";
              User = cfg.user;
              Group = cfg.group;
              ExecStart = "${cfg.package}/bin/loki --config.file=${cfg.dataDir}/loki.yaml";
              Restart = "on-failure";
              RestartSec = "10s";
              # Loki flushes in-memory data to chunks on stop; the default 90s
              # timeout can SIGKILL it mid-flush and leave a damaged WAL.
              TimeoutStopSec = "5min";
            };

          preStart = let
            lokiConfig =
              {
                auth_enabled = false;

                analytics = {
                  reporting_enabled = false;
                };

                server = {
                  http_listen_address = cfg.listenAddress;
                  http_listen_port = cfg.port;
                  grpc_listen_address = "127.0.0.1";
                  grpc_listen_port = cfg.grpcPort;
                  log_level = "info";
                };

                common = {
                  instance_addr = "127.0.0.1";
                  path_prefix = cfg.dataDir;
                  storage = {
                    filesystem = {
                      chunks_directory = "${cfg.dataDir}/chunks";
                      rules_directory = "${cfg.dataDir}/rules";
                    };
                  };
                  replication_factor = 1;
                  ring = {
                    kvstore = {
                      store = "inmemory";
                    };
                  };
                };

                query_range = {
                  results_cache = {
                    cache = {
                      embedded_cache = {
                        enabled = true;
                        max_size_mb = 100;
                      };
                    };
                  };
                };

                schema_config = {
                  configs = [
                    {
                      from = "2023-01-01";
                      store = "tsdb";
                      object_store = "filesystem";
                      schema = "v13";
                      index = {
                        prefix = "index_";
                        period = "24h";
                      };
                    }
                  ];
                };

                limits_config = {
                  retention_period = cfg.retention;
                  retention_stream = [
                    {
                      selector = ''{job="maintenance-log"}'';
                      priority = 1;
                      period = "17520h";
                    }
                  ];
                  max_query_series = 10000;
                  max_query_lookback = "17520h";
                  # Guardrails: a runaway unit must not fill /data on a laptop.
                  ingestion_rate_mb = 4;
                  ingestion_burst_size_mb = 8;
                  per_stream_rate_limit = "3MB";
                  per_stream_rate_limit_burst = "10MB";
                  reject_old_samples = true;
                  reject_old_samples_max_age = "168h";
                  max_entries_limit_per_query = 5000;
                };

                compactor = {
                  working_directory = "${cfg.dataDir}/compactor";
                  retention_enabled = true;
                  retention_delete_delay = "2h";
                  retention_delete_worker_count = 150;
                  delete_request_store = "filesystem";
                };

                ingester = {
                  wal = {
                    enabled = true;
                    dir = "${cfg.dataDir}/wal";
                    flush_on_shutdown = true;
                  };
                  lifecycler = {
                    address = "127.0.0.1";
                    ring = {
                      kvstore = {
                        store = "inmemory";
                      };
                      replication_factor = 1;
                    };
                  };
                };

                memberlist = {
                  join_members = [];
                };
              }
              // lib.optionalAttrs cfg.ruler.enable {
                ruler = {
                  storage = {
                    type = "local";
                    local.directory = "${cfg.dataDir}/rules";
                  };
                  rule_path = "${cfg.dataDir}/rules-tmp";
                  alertmanager_url = cfg.ruler.alertmanagerUrl;
                  ring.kvstore.store = "inmemory";
                  enable_api = true;
                };
              };

            jsonFile =
              builtins.toFile "loki.json"
              (builtins.toJSON lokiConfig);

            yamlTmp = "${cfg.dataDir}/loki.yaml.tmp";

            rulesJson =
              builtins.toFile "loki-rules.json"
              (builtins.toJSON {groups = cfg.ruler.groups;});
          in ''
            ${pkgs.remarshal}/bin/remarshal \
              -i ${jsonFile} \
              -o ${yamlTmp} \
              -if json \
              -of yaml

            install -m 660 -o ${cfg.user} -g ${cfg.group} ${yamlTmp} ${cfg.dataDir}/loki.yaml

            mkdir -p ${cfg.dataDir}/data ${cfg.dataDir}/chunks ${cfg.dataDir}/wal ${cfg.dataDir}/compactor
            ${lib.optionalString cfg.ruler.enable ''
              # "fake" is the tenant name Loki uses when auth_enabled = false.
              mkdir -p ${cfg.dataDir}/rules/fake ${cfg.dataDir}/rules-tmp
              ${pkgs.remarshal}/bin/remarshal -i ${rulesJson} -o ${cfg.dataDir}/rules/fake/journal.yaml -if json -of yaml
            ''}
            chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
          '';
        };

        # ----------------------------------------------------------------------------
        # NGINX REVERSE PROXY - Only configured if domain is set
        # ----------------------------------------------------------------------------
        services.nginx.enable = lib.mkIf (cfg.domain != null) true;
        services.nginx.virtualHosts = nixlabLib.mkNginxVirtualHost {
          inherit (cfg) domain listenAddress port enableSSL;
        };

        # ----------------------------------------------------------------------------
        # FIREWALL - Open necessary ports if requested
        # ----------------------------------------------------------------------------
        networking.firewall.allowedTCPPorts =
          lib.mkIf cfg.openFirewall
          (nixlabLib.mkFirewallPorts {
            inherit (cfg) domain listenAddress;
            servicePort = cfg.port;
            extraPorts = lib.optionals cfg.openGrpcFirewall [cfg.grpcPort];
          });
      }
      # Automatic recovery from a corrupt write-ahead log.
      (nixlabLib.mkWalSelfHeal {
        inherit pkgs;
        unit = "loki";
        walDir = "${cfg.dataDir}/wal";
        user = cfg.user;
        group = cfg.group;
      })
    ]);
  };
}
