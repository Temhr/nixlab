{self, ...}: {
  flake.nixosModules.stack--monitoring = {
    config,
    lib,
    hostMeta ? {},
    ...
  }: let
    cfg = config.services.nixlab-monitoring;
    svc = config.services;

    # Resolved ports. Single source of truth: ports.nix (mkDefault) or a plain
    # assignment in a host file. The stack never owns port numbers.
    port = {
      grafana = svc.grafana-nixlab.port;
      loki = svc.loki-nixlab.port;
      prometheus = svc.prometheus-nixlab.port;
      alertmanager = svc.alertmanager-nixlab.port;
      ntfy = svc.ntfy-nixlab.port;
    };
    scrapeJob = name: target: {
      job_name = name;
      static_configs = [{targets = [target];}];
    };
    loopback = p: "127.0.0.1:${toString p}";

    # Only services someone must reach leave loopback; the firewall still decides who.
    bindAddress = name:
      if cfg.listenAddress != null
      then cfg.listenAddress
      else if (cfg.access.interfaces != [] && lib.elem name cfg.access.expose) || lib.elem name cfg.access.peerReachable
      then "0.0.0.0"
      else "127.0.0.1";

    registry = self.lib.serviceRegistry {inherit config;};
    registryTcpTargets =
      lib.mapAttrsToList (_: e: "127.0.0.1:${toString e.port}")
      (lib.filterAttrs (k: _: registry.enabled.${k} or false) (registry.endpoints or {}));

    # The maintenance-log pipeline for Alloy (moved here from the Loki module).
    maintenanceAlloyConfig = ''
      // Collect maintenance logs
      local.file_match "maintenance" {
        path_targets = [{
          __address__ = "localhost",
          __path__    = "${svc.loki-nixlab.maintenance.logPath}",
        }]
      }

      loki.source.file "maintenance" {
        targets    = local.file_match.maintenance.targets
        forward_to = [loki.process.maintenance.receiver]
      }

      loki.process "maintenance" {
        forward_to = [loki.write.local.receiver]

        // Parse JSON logs
        stage.json {
          expressions = {
            timestamp = "timestamp",
            section   = "section",
            task      = "task",
            status    = "status",
            notes     = "notes",
            user      = "user",
          }
        }

        // Extract labels
        // Labels taken from the parsed JSON fields (empty string = same key name)
        stage.labels {
          values = {
            section = "",
            status  = "",
            user    = "",
          }
        }

        // Constant labels
        stage.static_labels {
          values = {
            job  = "maintenance-log",
            host = "${config.networking.hostName}",
          }
        }

        // Parse timestamp
        stage.timestamp {
          source = "timestamp"
          format = "RFC3339"
        }
      }
    '';

    mkIntegration = defaultTarget: what: {
      enable = lib.mkEnableOption "scraping and alerting for ${what}";
      target = lib.mkOption {
        type = lib.types.str;
        default = defaultTarget;
        description = "host:port of the ${what} metrics endpoint.";
      };
    };

    ntfyUrl = "http://127.0.0.1:${toString port.ntfy}/${cfg.notifications.ntfyTopic}";
    ntfyTemplate = {
      title = "[{{.status}}] {{(index .alerts 0).labels.host}}: {{(index .alerts 0).labels.alertname}}";
      message = ''{{range .alerts}}{{.annotations.summary}}{{"\n"}}{{.annotations.description}}{{"\n\n"}}{{end}}'';
    };

    # Tapping a notification opens Grafana (only when an external URL is resolved).
    clickParams = lib.optional (svc.grafana-nixlab.externalUrl != null) "click=${lib.escapeURL svc.grafana-nixlab.externalUrl}";

    mkNtfyReceiver = name: extraParams: let
      params =
        lib.optionals cfg.notifications.formatMessages [
          "tpl=1"
          "t=${lib.escapeURL ntfyTemplate.title}"
          "m=${lib.escapeURL ntfyTemplate.message}"
        ]
        ++ clickParams
        ++ extraParams;
    in {
      inherit name;
      webhook_configs = [
        ({
            url = ntfyUrl + lib.optionalString (params != []) "?${lib.concatStringsSep "&" params}";
            send_resolved = true;
          }
          // lib.optionalAttrs cfg.notifications.ntfyAuth.enable {
            http_config.basic_auth = {
              username = "alertmanager";
              password = "$NTFY_ALERTMANAGER_PASSWORD";
            };
          })
      ];
    };
  in {
    imports = [
      self.nixosModules.nsops--alertmanager
      self.nixosModules.nsops--grafana
      self.nixosModules.servc--loki-nixlab
      self.nixosModules.servc--prometheus-nixlab
      self.nixosModules.servc--ntfy-nixlab
      self.nixosModules.servc--maintenance-log-nixlab
      self.nixosModules.servc--alloy-nixlab
    ];

    options.services.nixlab-monitoring = {
      enable = lib.mkEnableOption "nixlab monitoring stack (Prometheus + Loki + Grafana + Alertmanager + ntfy)";

      listenAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Force one bind address for every service. Null (the default) binds each
          service on its own: services in access.expose (when access.interfaces is
          non-empty) and in access.peerReachable listen on 0.0.0.0, everything
          else on loopback.
        '';
      };

      publicHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = hostMeta.address or null;
        description = ''
          Host name or address that links in notifications and the UIs use.
          Defaults to this host's static address from hostsMeta. Set a name here
          (or a `domain` on a service) once nginx fronts it. Null leaves each
          service's own fallback.
        '';
      };

      access = {
        interfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["eno1"];
          description = ''
            Network interfaces on which the services in `expose` are reachable.
            Empty means loopback only. Use the wired interface (hostMeta.interfaces
            entries with type "ethernet"); never list a Wi-Fi interface.
          '';
        };
        expose = lib.mkOption {
          type = lib.types.listOf (lib.types.enum ["grafana" "ntfy" "alertmanager" "prometheus" "loki"]);
          default = ["grafana" "ntfy" "prometheus"];
          description = "Which services to open on access.interfaces.";
        };
        peerReachable = lib.mkOption {
          type = lib.types.listOf (lib.types.enum ["grafana" "ntfy" "alertmanager" "prometheus" "loki"]);
          default = [];
          description = ''
            Services that must listen beyond loopback because a source-restricted
            firewall rule admits specific peers (agents pushing logs to a hub, a hub
            probing the other hub). Unlike `expose`, this opens no firewall port.
          '';
        };
      };

      probes = {
        gateway = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = hostMeta.gateway or null;
          description = "Default gateway to ICMP-probe (from hostsMeta).";
        };
        hubs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = ["nixnas1" "nixnas2"];
          description = "Always-on hosts to ICMP-probe. This host is excluded. Never list laptops: they sleep.";
        };
        tcpFromRegistry = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "TCP-probe the loopback ports of the services enabled on this host (from the service registry).";
        };
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Open each service's port on every interface (the old behaviour).
          Prefer access.interfaces, which scopes the rules to chosen interfaces.
        '';
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/data";
        description = "Root directory; each service gets a subdirectory.";
      };

      loki = {
        retention = lib.mkOption {
          type = lib.types.str;
          default = "744h";
          description = "Loki log retention period (e.g. 744h = 31 days).";
        };
        maintenance.enable = lib.mkEnableOption "maintenance task logging integration";
      };

      prometheus = {
        maintenance.enable = lib.mkEnableOption "maintenance monitoring integration";
        scrapeInterval = lib.mkOption {
          type = lib.types.str;
          default = "30s";
          description = "Prometheus scrape and evaluation interval.";
        };
        retention = lib.mkOption {
          type = lib.types.str;
          default = "15d";
          description = "Prometheus retention time.";
        };
        retentionSize = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "8GB";
          description = "Prometheus size cap; set on laptops.";
        };
        maintenance.exporters.systemd = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable systemd unit exporter.";
        };
        maintenance.exporters.smartctl.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable smartctl disk health exporter.";
        };
      };

      ntfy = {
        cachePersist = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Persist ntfy message cache to disk (survives restarts).";
        };
      };

      # ── Cross-service wiring ───────────────────────────────────────────────
      notifications = {
        useNtfy = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Wire alertmanager to send alerts to the local ntfy instance via a
            webhook receiver. Set to false to define your own alertmanager
            receivers (Slack, PagerDuty, etc.) instead — see
            services.alertmanager-nixlab.receivers on the host config.
          '';
        };

        ntfyTopic = lib.mkOption {
          type = lib.types.str;
          default = "alerts";
          description = "ntfy topic that alertmanager will publish to.";
        };
        formatMessages = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use ntfy message templating so notifications show alert summary/description instead of raw JSON. Requires ntfy >= 2.10.";
        };
        ntfyAuth.enable = lib.mkEnableOption "ntfy authentication with an Alertmanager writer and a reader account (needs NTFY_*_PASSWORD in the alertmanager secrets file)";
        separateCritical = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Route severity=critical to a separate ntfy receiver with max priority and a warning tag.";
        };
      };

      integrations = {
        traefik = mkIntegration "127.0.0.1:8082" "traefik";
        cadvisor = mkIntegration "127.0.0.1:8080" "cAdvisor container metrics";
        postgres = mkIntegration "127.0.0.1:9187" "the PostgreSQL exporter";
      };
    };

    config = lib.mkIf cfg.enable {
      # Override contract (hosts/<name>.nix):
      #   * Tunables set here are lib.mkDefault: override via services.nixlab-monitoring.*
      #     OR directly on services.<x>-nixlab.* — both work.
      #   * Wiring (datasources, scrape jobs, receivers, alertmanagerTargets) is plain and
      #     additive; extend it, don't replace it.
      #   * Ports are never set here; see ports.nix / host plain assignment.

      services.grafana-nixlab = {
        enable = true;
        uid = lib.mkDefault 742;
        gid = lib.mkDefault 742;
        listenAddress = lib.mkDefault (bindAddress "grafana");
        dataDir = lib.mkDefault "${cfg.dataDir}/grafana";
        openFirewall = lib.mkDefault cfg.openFirewall;
      };

      services.loki-nixlab = {
        enable = true;
        uid = lib.mkDefault 740;
        gid = lib.mkDefault 740;
        listenAddress = lib.mkDefault (bindAddress "loki");
        dataDir = lib.mkDefault "${cfg.dataDir}/loki";
        openFirewall = lib.mkDefault cfg.openFirewall;
        retention = lib.mkDefault cfg.loki.retention;
        maintenance.enable = lib.mkDefault cfg.loki.maintenance.enable;
      };

      services.prometheus-nixlab = {
        enable = true;
        uid = lib.mkDefault 743;
        gid = lib.mkDefault 743;
        scrapeInterval = lib.mkDefault cfg.prometheus.scrapeInterval;
        evaluationInterval = lib.mkDefault cfg.prometheus.scrapeInterval;
        retention = lib.mkDefault cfg.prometheus.retention;
        retentionSize = lib.mkDefault cfg.prometheus.retentionSize;
        listenAddress = lib.mkDefault (bindAddress "prometheus");
        dataDir = lib.mkDefault "${cfg.dataDir}/prometheus";
        openFirewall = lib.mkDefault cfg.openFirewall;
        maintenance = {
          enable = lib.mkDefault cfg.prometheus.maintenance.enable;
          exporters.systemd = lib.mkDefault cfg.prometheus.maintenance.exporters.systemd;
          exporters.smartctl.enable = lib.mkDefault cfg.prometheus.maintenance.exporters.smartctl.enable;
        };
      };

      services.alertmanager-nixlab = {
        enable = true;
        listenAddress = lib.mkDefault (bindAddress "alertmanager");
        openFirewall = lib.mkDefault cfg.openFirewall;
        defaultReceiver =
          if cfg.notifications.useNtfy
          then "ntfy"
          else "null";
        receivers =
          [{name = "null";}]
          ++ lib.optionals cfg.notifications.useNtfy [(mkNtfyReceiver "ntfy" ["tags=warning"]) (mkNtfyReceiver "ntfy-low" ["p=2" "tags=memo"])]
          ++ lib.optionals (cfg.notifications.useNtfy && cfg.notifications.separateCritical) [
            (mkNtfyReceiver "ntfy-critical" ["p=5" "tags=rotating_light"])
          ];

        route.routes =
          lib.optionals cfg.notifications.useNtfy [
            {
              receiver = "ntfy-low";
              matchers = ["category=\"maintenance\""];
              groupWait = "1m";
              repeatInterval = "72h";
            }
          ]
          ++ lib.optionals (cfg.notifications.useNtfy && cfg.notifications.separateCritical) [
            {
              receiver = "ntfy-critical";
              matchers = ["severity=\"critical\""];
              groupWait = "10s";
              repeatInterval = "1h";
            }
          ];
      };

      services.ntfy-nixlab = {
        enable = true;
        uid = lib.mkDefault 744;
        gid = lib.mkDefault 744;
        listenAddress = lib.mkDefault (bindAddress "ntfy");
        dataDir = lib.mkDefault "${cfg.dataDir}/ntfy";
        openFirewall = lib.mkDefault cfg.openFirewall;
        cacheFile = lib.mkIf cfg.ntfy.cachePersist (lib.mkDefault "${cfg.dataDir}/ntfy/cache.db");
      };

      # Links in notifications, redirects and the web UIs.
      services.grafana-nixlab.externalUrl = lib.mkIf (cfg.publicHost != null) (lib.mkDefault "http://${cfg.publicHost}:${toString port.grafana}/");
      services.alertmanager-nixlab.externalUrl = lib.mkIf (cfg.publicHost != null) (lib.mkDefault "http://${cfg.publicHost}:${toString port.alertmanager}/");
      services.prometheus-nixlab.externalUrl = lib.mkIf (cfg.publicHost != null) (lib.mkDefault "http://${cfg.publicHost}:${toString port.prometheus}/");
      services.ntfy-nixlab.externalUrl = lib.mkIf (cfg.publicHost != null) (lib.mkDefault "http://${cfg.publicHost}:${toString port.ntfy}");
      services.grafana-nixlab.prometheusUrl = lib.mkDefault (
        if svc.prometheus-nixlab.externalUrl != null
        then svc.prometheus-nixlab.externalUrl
        else "http://localhost:${toString port.prometheus}"
      );

      # Interface-scoped exposure: only the chosen services, only on the chosen interfaces.
      networking.firewall.interfaces = lib.genAttrs cfg.access.interfaces (_: {
        allowedTCPPorts = map (name: port.${name}) cfg.access.expose;
      });

      services.ntfy-nixlab.auth = lib.mkIf cfg.notifications.ntfyAuth.enable {
        enable = true;
        defaultAccess = "deny-all";
        environmentFile = config.sops.secrets.ALERTMANAGER_ENV.path;
        users = [
          {
            name = "alertmanager";
            passwordEnvVar = "NTFY_ALERTMANAGER_PASSWORD";
            topics = [
              {
                topic = cfg.notifications.ntfyTopic;
                access = "write-only";
              }
            ];
          }
          {
            name = "reader";
            passwordEnvVar = "NTFY_READER_PASSWORD";
            topics = [
              {
                topic = cfg.notifications.ntfyTopic;
                access = "read-only";
              }
            ];
          }
        ];
      };

      services.prometheus-nixlab.maintenance.exporters.blackbox = {
        icmpTargets = lib.mkDefault (
          lib.optional (cfg.probes.gateway != null) cfg.probes.gateway
          ++ lib.filter (a: a != (hostMeta.address or ""))
          (map (h: self.lib.hostsMeta.${h}.address) cfg.probes.hubs)
        );
        tcpTargets = lib.mkIf cfg.probes.tcpFromRegistry (lib.mkDefault registryTcpTargets);
      };

      services.loki-nixlab.ruler = {
        enable = lib.mkDefault true;
        alertmanagerUrl = "http://127.0.0.1:${toString port.alertmanager}";
        groups = [
          {
            name = "journal";
            interval = "1m";
            rules = [
              {
                alert = "JournalOOMKill";
                expr = ''sum by (host) (count_over_time({job="systemd-journal", transport="kernel"} |~ "(?i)out of memory: kill|oom-kill" [5m])) > 0'';
                labels = {
                  severity = "critical";
                  category = "os";
                  checklist_section = "II.5";
                  instance = "{{ $labels.host }}";
                };
                annotations.summary = "OOM kill on {{ $labels.host }}";
              }
              {
                alert = "KernelFilesystemError";
                expr = ''sum by (host) (count_over_time({job="systemd-journal", transport="kernel"} |~ "EXT4-fs error|XFS.*(Corruption|I/O error)|BTRFS (error|critical)|Remounting filesystem read-only|I/O error, dev" [5m])) > 0'';
                labels = {
                  severity = "critical";
                  category = "storage";
                  checklist_section = "III.8";
                  instance = "{{ $labels.host }}";
                };
                annotations.summary = "Kernel filesystem or I/O error on {{ $labels.host }}";
              }
              {
                alert = "NvidiaXid";
                expr = ''sum by (host) (count_over_time({job="systemd-journal", transport="kernel"} |= "NVRM: Xid" [5m])) > 0'';
                labels = {
                  severity = "warning";
                  category = "hardware";
                  checklist_section = "I.1";
                  instance = "{{ $labels.host }}";
                };
                annotations.summary = "NVIDIA Xid fault on {{ $labels.host }}";
              }
              {
                alert = "SSHAuthFailureBurst";
                expr = ''sum by (host) (count_over_time({job="systemd-journal", unit="sshd.service"} |~ "Failed password|Invalid user|authentication failure" [10m])) > 20'';
                labels = {
                  severity = "warning";
                  category = "security";
                  checklist_section = "IV.10";
                  instance = "{{ $labels.host }}";
                };
                annotations.summary = "SSH authentication failure burst on {{ $labels.host }}";
              }
            ];
          }
        ];
      };

      # The helper follows Loki's maintenance settings so the file Alloy tails and the file the helper writes are the same.
      services.maintenance-log-nixlab = {
        enable = lib.mkDefault svc.loki-nixlab.maintenance.enable;
        logPath = lib.mkDefault svc.loki-nixlab.maintenance.logPath;
        textfileDir = lib.mkIf cfg.prometheus.maintenance.enable "/var/lib/node_exporter";
      };

      services.alloy-nixlab = {
        enable = lib.mkDefault svc.loki-nixlab.enableAlloy;
        port = lib.mkDefault svc.loki-nixlab.alloyPort;
        package = lib.mkDefault svc.loki-nixlab.alloyPackage;
        lokiUrl = lib.mkDefault "http://127.0.0.1:${toString port.loki}/loki/api/v1/push";
        uid = lib.mkDefault 741;
        gid = lib.mkDefault 741;
        extraConfig = lib.optionalString svc.loki-nixlab.maintenance.enable maintenanceAlloyConfig;
      };

      # NEW — Grafana ↔ Prometheus/Loki datasource auto-provisioning.
      # This is the missing "synergy" piece: dashboards assume these exist,
      # nothing previously declared them.
      services.grafana-nixlab.provisioning.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          uid = "prometheus";
          url = "http://127.0.0.1:${toString port.prometheus}";
          isDefault = true;
        }
        {
          name = "Loki";
          type = "loki";
          uid = "loki";
          url = "http://127.0.0.1:${toString port.loki}";
        }
        {
          name = "Alertmanager";
          type = "alertmanager";
          uid = "alertmanager";
          url = "http://127.0.0.1:${toString port.alertmanager}";
          jsonData = {
            implementation = "prometheus";
            handleGrafanaManagedAlerts = false;
          };
        }
      ];

      # NEW — Prometheus scrapes ntfy's own /metrics, closing the last gap
      # in "every service in this stack is observed by every other."
      services.prometheus-nixlab.extraScrapeConfigs =
        [
          (scrapeJob "ntfy" (loopback port.ntfy))
          (scrapeJob "loki" (loopback port.loki))
          (scrapeJob "grafana" (loopback port.grafana))
          (scrapeJob "alertmanager" (loopback port.alertmanager))
        ]
        ++ lib.optional svc.loki-nixlab.enableAlloy
        (scrapeJob "alloy" (loopback svc.loki-nixlab.alloyPort))
        ++ lib.optional cfg.integrations.traefik.enable (scrapeJob "traefik" cfg.integrations.traefik.target)
        ++ lib.optional cfg.integrations.cadvisor.enable (scrapeJob "cadvisor" cfg.integrations.cadvisor.target)
        ++ lib.optional cfg.integrations.postgres.enable (scrapeJob "postgres" cfg.integrations.postgres.target);

      services.prometheus-nixlab.maintenance.alerts.features = {
        traefik = lib.mkDefault cfg.integrations.traefik.enable;
        containers = lib.mkDefault cfg.integrations.cadvisor.enable;
        postgres = lib.mkDefault cfg.integrations.postgres.enable;
      };

      # Point Prometheus at Alertmanager. Neither servc--prometheus-nixlab nor
      # servc--alertmanager-nixlab wire this automatically since they have no
      # knowledge of each other — it has to happen at the aggregator level.
      services.prometheus-nixlab.alertmanagerTargets = [
        "127.0.0.1:${toString port.alertmanager}"
      ];
    };
  };
}
