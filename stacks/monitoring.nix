{self, ...}: {
  flake.nixosModules.stack--monitoring = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.nixlab-monitoring;
  in {
    imports = [
      self.nixosModules.nsops--alertmanager
      self.nixosModules.nsops--grafana
      self.nixosModules.servc--loki-nixlab
      self.nixosModules.servc--prometheus-nixlab
      self.nixosModules.servc--ntfy-nixlab
    ];

    options.services.nixlab-monitoring = {
      enable = lib.mkEnableOption "nixlab monitoring stack (Prometheus + Loki + Grafana + Alertmanager + ntfy)";

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "IP address all services bind to.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports for all services.";
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/data";
        description = "Root directory; each service gets a subdirectory.";
      };

      ports = {
        grafana = lib.mkOption {
          type = lib.types.port;
          default = 3101;
          description = "Grafana HTTP port.";
        };
        loki = lib.mkOption {
          type = lib.types.port;
          default = 3100;
          description = "Loki HTTP port.";
        };
        prometheus = lib.mkOption {
          type = lib.types.port;
          default = 9090;
          description = "Prometheus HTTP port.";
        };
        alertmanager = lib.mkOption {
          type = lib.types.port;
          default = 9093;
          description = "Alertmanager HTTP port.";
        };
        ntfy = lib.mkOption {
          type = lib.types.port;
          default = 2586;
          description = "Port for ntfy to listen on.";
        };
      };

      loki = {
        grpcPort = lib.mkOption {
          type = lib.types.port;
          default = 9096;
          description = "Loki gRPC port.";
        };
        retention = lib.mkOption {
          type = lib.types.str;
          default = "744h";
          description = "Loki log retention period (e.g. 744h = 31 days).";
        };
        maintenance.enable = lib.mkEnableOption "maintenance task logging integration";
      };

      prometheus = {
        maintenance.enable = lib.mkEnableOption "maintenance monitoring integration";
        maintenance.exporters.systemd = lib.mkOption {
          type = lib.types.bool;
          default = true;
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
      };
    };

    config = lib.mkIf cfg.enable {
      services.grafana-nixlab = {
        enable = true;
        port = lib.mkDefault cfg.ports.grafana;
        listenAddress = cfg.listenAddress;
        dataDir = "${cfg.dataDir}/grafana";
        openFirewall = cfg.openFirewall;
      };

      services.loki-nixlab = {
        enable = true;
        port = lib.mkDefault cfg.ports.loki;
        grpcPort = lib.mkDefault cfg.loki.grpcPort;
        listenAddress = cfg.listenAddress;
        dataDir = "${cfg.dataDir}/loki";
        openFirewall = cfg.openFirewall;
        retention = cfg.loki.retention;
        maintenance = cfg.loki.maintenance;
      };

      services.prometheus-nixlab = {
        enable = true;
        port = lib.mkDefault cfg.ports.prometheus;
        listenAddress = cfg.listenAddress;
        dataDir = "${cfg.dataDir}/prometheus";
        openFirewall = cfg.openFirewall;
        maintenance = cfg.prometheus.maintenance;
      };

      # NEW — Grafana ↔ Prometheus/Loki datasource auto-provisioning.
      # This is the missing "synergy" piece: dashboards assume these exist,
      # nothing previously declared them.
      services.grafana-nixlab.provisioning.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:${toString cfg.ports.prometheus}";
          isDefault = true;
        }
        {
          name = "Loki";
          type = "loki";
          url = "http://127.0.0.1:${toString cfg.ports.loki}";
        }
      ];

      # NEW — Prometheus scrapes ntfy's own /metrics, closing the last gap
      # in "every service in this stack is observed by every other."
      services.prometheus-nixlab.extraScrapeConfigs = [
        {
          job_name = "ntfy";
          static_configs = [{targets = ["127.0.0.1:${toString cfg.ports.ntfy}"];}];
        }
      ];

      # Point Prometheus at Alertmanager. Neither servc--prometheus-nixlab nor
      # servc--alertmanager-nixlab wire this automatically since they have no
      # knowledge of each other — it has to happen at the aggregator level.
      services.prometheus.alertmanagers = [
        {
          static_configs = [
            {
              targets = ["127.0.0.1:${toString cfg.ports.alertmanager}"];
            }
          ];
        }
      ];

      services.alertmanager-nixlab = {
        enable = true;
        port = lib.mkDefault cfg.ports.alertmanager;
        listenAddress = cfg.listenAddress;
        openFirewall = cfg.openFirewall;

        defaultReceiver =
          if cfg.notifications.useNtfy
          then "ntfy"
          else "null";

        receivers =
          [{name = "null";}]
          ++ lib.optionals cfg.notifications.useNtfy [
            {
              name = "ntfy";
              webhook_configs = [
                {
                  # Loopback, not cfg.listenAddress: alertmanager talks to ntfy
                  # on the same host regardless of ntfy's external bind address.
                  url = "http://127.0.0.1:${toString cfg.ports.ntfy}/${cfg.notifications.ntfyTopic}";
                  send_resolved = true;
                }
              ];
            }
          ];
      };

      services.ntfy-nixlab = {
        enable = true;
        port = lib.mkDefault cfg.ports.ntfy;
        listenAddress = cfg.listenAddress;
        dataDir = "${cfg.dataDir}/ntfy";
        openFirewall = cfg.openFirewall;
        cacheFile = lib.mkIf cfg.ntfy.cachePersist "${cfg.dataDir}/ntfy/cache.db";
      };
    };
  };
}
