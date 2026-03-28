{self, ...}: {
  flake.nixosModules.nixzen = {...}: {
    networking.hostName = "nixzen";
    imports = [
      (import ../nixzen.nix)
      self.nixosModules.auto-backup-phone-media
    ];
  };

  flake.nixosConfigurations.nixzen = self.lib.mkHost {
    modules = [
      self.nixosModules.hw-common-global
      self.nixosModules.hw-common-optional
      self.nixosModules.hw-zb15g2-k1
      self.nixosModules.hosts-global
      self.nixosModules.hosts-optional
      self.nixosModules.cachix
      self.nixosModules.nixzen
      self.nixosModules.grafana-nixlab
      self.nixosModules.secrets-grafana
      self.nixosModules.loki-nixlab
      self.nixosModules.prometheus-nixlab
      self.nixosModules.syncthing-nixlab
    ];
  };
}
