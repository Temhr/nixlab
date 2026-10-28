{self, ...}: {
  flake.nixosModules.hosts--profl--base = {lib, ...}: {
    imports = [
      self.nixosModules.hosts--core--boot-loader
      self.nixosModules.hosts--core--display-manager
      self.nixosModules.hosts--core--home-manager-config
      self.nixosModules.hosts--core--locale
      self.nixosModules.hosts--core--networking
      self.nixosModules.hosts--core--nginx
      self.nixosModules.hosts--core--open-ssh
      self.nixosModules.hosts--core--sops
      self.nixosModules.hosts--core--system
      self.nixosModules.hosts--core--users-main
      self.nixosModules.hosts--core--users-hm
      self.nixosModules.hosts--core--users-sys
      self.nixosModules.hosts--core--utilities

      self.nixosModules.hosts--autom--backup-home
      self.nixosModules.hosts--autom--flake-update
      self.nixosModules.hosts--autom--nix-gc
      self.nixosModules.hosts--autom--nixlab-gpull
      self.nixosModules.hosts--autom--nixos-upgrade
      self.nixosModules.hosts--autom--ping-watchdog

      self.nixosModules.hosts--hardw--audio
      self.nixosModules.hosts--hardw--bluetooth
      self.nixosModules.hosts--hardw--power-management

      self.nixosModules.nsops--homepage
      self.nixosModules.nsops--ssh-keys
      self.nixosModules.stack--monitoring
    ];

    ## Shared system-wide default user option
    nixlab.mainUser = lib.mkDefault "temhr";

    services.timesyncd.enable = true;

    # Make time-sync.target mean "the clock is actually set". NixOS does not ship
    # systemd-time-wait-sync by default, so without this nothing waits for NTP and
    # services ordered after the target start on a wrong clock.
    systemd.additionalUpstreamSystemUnits = ["systemd-time-wait-sync.service"];
    systemd.services.systemd-time-wait-sync = {
      wantedBy = ["time-sync.target"];
      # An offline laptop would otherwise wait this long before the login screen.
      serviceConfig.TimeoutStartSec = "60s";
    };

    services.homepage-nixlab = {
      enable = true;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/homepage";
    };
    services.nixlab-monitoring = {
      enable = true;
      dataDir = "/data";
      loki.maintenance.enable = true;
      prometheus.maintenance.enable = true;
      prometheus.maintenance.exporters.smartctl.enable = true;
    };
  };
}
