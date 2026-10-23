{self, ...}: {
  flake.nixosModules.stack--monitoring = {
    config,
    lib,
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
      # Override contract (hosts/<name>.nix):
      #   * Tunables set here are lib.mkDefault: override via services.nixlab-monitoring.*
      #     OR directly on services.<x>-nixlab.* — both work.
      #   * Wiring (datasources, scrape jobs, receivers, alertmanagerTargets) is plain and
      #     additive; extend it, don't replace it.
      #   * Ports are never set here; see ports.nix / host plain assignment.

      services.grafana-nixlab = {
        enable = true;
        listenAddress = lib.mkDefault cfg.listenAddress;
        dataDir = lib.mkDefault "${cfg.dataDir}/grafana";
        openFirewall = lib.mkDefault cfg.openFirewall;
      };

      services.loki-nixlab = {
        enable = true;
        listenAddress = lib.mkDefault cfg.listenAddress;
        dataDir = lib.mkDefault "${cfg.dataDir}/loki";
        openFirewall = lib.mkDefault cfg.openFirewall;
        retention = lib.mkDefault cfg.loki.retention;
        maintenance.enable = lib.mkDefault cfg.loki.maintenance.enable;
      };

      services.prometheus-nixlab = {
        enable = true;
        listenAddress = lib.mkDefault cfg.listenAddress;
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
        listenAddress = lib.mkDefault cfg.listenAddress;
        openFirewall = lib.mkDefault cfg.openFirewall;
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
                  url = "http://127.0.0.1:${toString port.ntfy}/${cfg.notifications.ntfyTopic}";
                  send_resolved = true;
                }
              ];
            }
          ];
      };

      services.ntfy-nixlab = {
        enable = true;
        listenAddress = lib.mkDefault cfg.listenAddress;
        dataDir = lib.mkDefault "${cfg.dataDir}/ntfy";
        openFirewall = lib.mkDefault cfg.openFirewall;
        cacheFile = lib.mkIf cfg.ntfy.cachePersist (lib.mkDefault "${cfg.dataDir}/ntfy/cache.db");
      };

      # NEW — Grafana ↔ Prometheus/Loki datasource auto-provisioning.
      # This is the missing "synergy" piece: dashboards assume these exist,
      # nothing previously declared them.
      services.grafana-nixlab.provisioning.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:${toString port.prometheus}";
          isDefault = true;
        }
        {
          name = "Loki";
          type = "loki";
          url = "http://127.0.0.1:${toString port.loki}";
        }
      ];

      # NEW — Prometheus scrapes ntfy's own /metrics, closing the last gap
      # in "every service in this stack is observed by every other."
      services.prometheus-nixlab.extraScrapeConfigs = [
        {
          job_name = "ntfy";
          static_configs = [{targets = ["127.0.0.1:${toString port.ntfy}"];}];
        }
      ];

      # Point Prometheus at Alertmanager. Neither servc--prometheus-nixlab nor
      # servc--alertmanager-nixlab wire this automatically since they have no
      # knowledge of each other — it has to happen at the aggregator level.
      services.prometheus-nixlab.alertmanagerTargets = [
        "127.0.0.1:${toString port.alertmanager}"
      ];
    };
  };
}
