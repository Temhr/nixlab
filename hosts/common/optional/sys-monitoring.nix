{...}: {
  flake.nixosModules.sys--monitoring = {lib, ...}: {
    # All three services default to disabled.
    # Enable per-host by setting enable = true in the host file.

    services.grafana-nixlab = lib.mkDefault {
      enable = false;
      port = 3101;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/grafana";
      dashboards = {
        maintenance = {
          path = ../modules/nixos/grafana/dashboards/maintenance-checklist.json;
          folder = "maintenance";
          editable = true;
        };
        system-overview = {
          path = ../modules/nixos/grafana/dashboards/system-overview.json;
          folder = "maintenance";
          editable = true;
        };
      };
    };

    services.loki-nixlab = lib.mkDefault {
      enable = false;
      port = 3100;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/loki";
      maintenance.enable = true;
    };

    services.prometheus-nixlab = lib.mkDefault {
      enable = false;
      port = 9090;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/prometheus";
      maintenance.enable = true;
      maintenance.exporters.systemd = true;
      maintenance.exporters.smartctl.enable = true;
    };
  };
}
