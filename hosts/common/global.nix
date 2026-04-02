{self, ...}: {
  flake.nixosModules.hosts--c-global = {...}: {
    imports = [
      ./_global
      self.nixosModules.systm--ignore-lid
      self.nixosModules.systm--cachix
      self.nixosModules.servc--glance-nixlab
      self.nixosModules.servc--monitoring-nixlab
      self.nixosModules.servc--grafana-nixlab
      self.nixosModules.secrets--grafana
      self.nixosModules.servc--loki-nixlab
      self.nixosModules.servc--prometheus-nixlab
    ];
    services.glance-nixlab = {
      enable = true;
      port = 3004;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/glance";
    };
    services.nixlab-monitoring = {
      enable = true;
      dataDir = "/data";
      openFirewall = true;
      ports.grafana = 3101;
      ports.loki = 3100;
      ports.prometheus = 9090;
      loki.maintenance.enable = true;
      prometheus.maintenance.enable = true;
      prometheus.maintenance.exporters.systemd = true;
      prometheus.maintenance.exporters.smartctl.enable = true;
    };
  };
}
