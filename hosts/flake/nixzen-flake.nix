{self, ...}: {
  flake.nixosModules.hosts--nixzen = {...}: {
    networking.hostName = "nixzen";
    imports = [
      (import ../nixzen.nix)
    ];
  };

  flake.nixosConfigurations.nixzen = self.lib.mkHost {
    modules = [
      self.nixosModules.hw--c-global
      self.nixosModules.hw--c-optional--driver-nvidia
      self.nixosModules.hw--zb15g2-k1
      self.nixosModules.hosts--nixzen
      self.nixosModules.hosts--c-global
      self.nixosModules.hosts--c-optional--development
      self.nixosModules.hosts--c-optional--education
      self.nixosModules.hosts--c-optional--games
      self.nixosModules.hosts--c-optional--media
      self.nixosModules.hosts--c-optional--productivity
      self.nixosModules.hosts--c-optional--virtualizations
      self.nixosModules.sys--auto-backup-phone-media
      self.nixosModules.sys--cachix
      self.nixosModules.sys--gui-shells
      self.nixosModules.sys--ignore-lid
      self.nixosModules.sys--monitoring
      self.nixosModules.svc--grafana-nixlab
      self.nixosModules.secrets--grafana
      self.nixosModules.svc--loki-nixlab
      self.nixosModules.svc--prometheus-nixlab
      self.nixosModules.svc--syncthing-nixlab
    ];
  };
}
