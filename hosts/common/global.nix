{self, ...}: {
  flake.nixosModules.hosts--c-global = {...}: {
    imports = [
      ./_global
      self.nixosModules.hosts--c-opt--development
      self.nixosModules.hosts--c-opt--education
      self.nixosModules.hosts--c-opt--games
      self.nixosModules.hosts--c-opt--media
      self.nixosModules.hosts--c-opt--productivity
      self.nixosModules.hosts--c-opt--virtualizations
      self.nixosModules.systm--ignore-lid
      self.nixosModules.systm--cachix
      self.nixosModules.systm--gui-shells
      self.nixosModules.systm--home-manager-config
      self.nixosModules.servc--homepage-nixlab
      self.nixosModules.nsops--homepage
      self.nixosModules.servc--monitoring-nixlab
      self.nixosModules.systm--networking
      self.nixosModules.nsops--ssh-keys
      self.nixosModules.systm--auto-flake-update
      self.nixosModules.systm--auto-nixlab-gpull
    ];

    services.ignoreLid = {
      enable = true;
      # Optional:
      disableSleepTargets = true;
    };
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
      zfs.enable = false;   # default for all hosts
    };

    # Define your Flatpak packages here
    flatpakPackages = [
      "net.davidotek.pupgui2" # ProtonUp-Qt Install Wine- and Proton-based compatibility tools
    ];
  };
}
