{self, ...}: {
  flake.nixosModules.hosts--c-global = {...}: {
    imports = [
      ./_global
      self.nixosModules.systm--ignore-lid
      self.nixosModules.systm--cachix
      self.nixosModules.servc--homepage-nixlab
      self.nixosModules.servc--monitoring-nixlab
    ];
    services.homepage-nixlab = {
      enable = true;
      port = 3000;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/homepage";
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
