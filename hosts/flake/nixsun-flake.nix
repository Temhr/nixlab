{self, ...}: {
  flake.nixosModules.hosts--nixsun = {...}: {
    networking.hostName = "nixsun";
    imports = [(import ../nixsun.nix)];
  };

  flake.nixosConfigurations.nixsun = self.lib.mkHost {
    modules = [
      self.nixosModules.hw--c-global
      self.nixosModules.hw--c-optional--driver-nvidia
      self.nixosModules.hw--zb17g1-k4
      self.nixosModules.hosts--c-global
      self.nixosModules.hosts--c-optional
      self.nixosModules.sys--cachix
      self.nixosModules.hosts--nixsun
      self.nixosModules.svc--grafana-nixlab
      self.nixosModules.secrets--grafana
      self.nixosModules.svc--loki-nixlab
      self.nixosModules.svc--prometheus-nixlab
    ];
  };
}
