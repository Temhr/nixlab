{self, ...}: {
  flake.nixosModules.nixsun = {...}: {
    networking.hostName = "nixsun";
    imports = [(import ../nixsun.nix)];
  };

  flake.nixosConfigurations.nixsun = self.lib.mkHost {
    modules = [
      self.nixosModules.hw-common-global
      self.nixosModules.hw-common-optional
      self.nixosModules.hw-zb17g1-k4
      self.nixosModules.hosts-global
      self.nixosModules.hosts-optional
      self.nixosModules.cachix
      self.nixosModules.nixsun
      self.nixosModules.grafana-nixlab
      self.nixosModules.secrets-grafana
      self.nixosModules.loki-nixlab
      self.nixosModules.prometheus-nixlab
    ];
  };
}
