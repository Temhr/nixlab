{self, ...}: {
  flake.nixosModules.hosts--nixsun = {...}: {
    networking.hostName = "nixsun";
    imports = [(import ../nixsun.nix)];
  };

  flake.nixosConfigurations.nixsun = self.lib.mkHost {
    modules = [
      self.nixosModules.hw--common-global
      self.nixosModules.hw--common-optional
      self.nixosModules.hw--zb17g1-k4
      self.nixosModules.hosts--common-global
      self.nixosModules.hosts--common-optional
      self.nixosModules.sys--cachix
      self.nixosModules.hosts--nixsun
      self.nixosModules.svc--grafana-nixlab
      self.nixosModules.secrets--grafana
      self.nixosModules.svc--loki-nixlab
      self.nixosModules.svc--prometheus-nixlab
    ];
  };
}
