{self, ...}: {
  flake.nixosModules.hosts--nixtop = {...}: {
    networking.hostName = "nixtop";
    imports = [(import ../nixtop.nix)];
  };

  flake.nixosConfigurations.nixtop = self.lib.mkHost {
    modules = [
      self.nixosModules.hw--c-global
      self.nixosModules.hw--c-optional--driver-nvidia
      self.nixosModules.hw--zb17g2-k5
      self.nixosModules.hosts--nixtop
      self.nixosModules.hosts--c-global
      self.nixosModules.hosts--c-optional--development
      self.nixosModules.hosts--c-optional--education
      self.nixosModules.hosts--c-optional--games
      self.nixosModules.hosts--c-optional--media
      self.nixosModules.hosts--c-optional--productivity
      self.nixosModules.hosts--c-optional--virtualizations
      self.nixosModules.sys--cachix
      self.nixosModules.sys--gui-shells
      self.nixosModules.sys--ignore-lid
      self.nixosModules.sys--monitoring
      self.nixosModules.svc--grafana-nixlab
      self.nixosModules.secrets--grafana
      self.nixosModules.svc--loki-nixlab
      self.nixosModules.svc--prometheus-nixlab
      self.nixosModules.svc--waydroid-nixlab
    ];
  };
}
