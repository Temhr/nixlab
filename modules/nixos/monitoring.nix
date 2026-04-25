{self, ...}: {
  flake.nixosModules.servc--monitoring-nixlab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.nixlab-monitoring;
  in {
    imports = [
      self.nixosModules.servc--grafana-nixlab
      self.nixosModules.nsops--grafana
      self.nixosModules.servc--loki-nixlab
      self.nixosModules.servc--prometheus-nixlab
    ];
    options.services.nixlab-monitoring = {
      enable = lib.mkEnableOption "nixlab monitoring stack (Prometheus + Loki + Grafana)";

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "IP address all three services bind to.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports for all three services.";
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
        lokiGrpc = lib.mkOption {
          type = lib.types.port;
          default = 9096;
          description = "Loki gRPC port.";
        };
        prometheus = lib.mkOption {
          type = lib.types.port;
          default = 9090;
          description = "Prometheus HTTP port.";
        };
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
    };

    config = lib.mkIf cfg.enable {
      services.grafana-nixlab = {
        enable = true;
        port = cfg.ports.grafana;
        listenAddress = cfg.listenAddress;
        dataDir = "${cfg.dataDir}/grafana";
        openFirewall = cfg.openFirewall;
      };

      services.loki-nixlab = {
        enable = true;
        port = cfg.ports.loki;
        grpcPort = cfg.ports.lokiGrpc;
        listenAddress = cfg.listenAddress;
        dataDir = "${cfg.dataDir}/loki";
        openFirewall = cfg.openFirewall;
        retention = cfg.loki.retention;
        maintenance = cfg.loki.maintenance;
      };

      services.prometheus-nixlab = {
        enable = true;
        port = cfg.ports.prometheus;
        listenAddress = cfg.listenAddress;
        dataDir = "${cfg.dataDir}/prometheus";
        openFirewall = cfg.openFirewall;
        maintenance = cfg.prometheus.maintenance;
      };
    };
  };
}
