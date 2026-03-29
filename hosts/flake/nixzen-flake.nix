{self, ...}: {
  flake.nixosModules.hosts--nixzen = {...}: {
    networking.hostName = "nixzen";
    imports = [
      (import ../nixzen.nix)
      self.nixosModules.sys--auto-backup-phone-media
    ];
  };

  flake.nixosConfigurations.nixzen = self.lib.mkHost {
    modules = [
      self.nixosModules.hw--c-global
      self.nixosModules.hw--c-optional--driver-nvidia
      self.nixosModules.hw--zb15g2-k1
      self.nixosModules.hosts--c-global
      self.nixosModules.hosts--c-optional
      self.nixosModules.sys--cachix
      self.nixosModules.hosts--nixzen
      self.nixosModules.svc--grafana-nixlab
      self.nixosModules.secrets--grafana
      self.nixosModules.svc--loki-nixlab
      self.nixosModules.svc--prometheus-nixlab
      self.nixosModules.svc--syncthing-nixlab
    ];
  };
}
