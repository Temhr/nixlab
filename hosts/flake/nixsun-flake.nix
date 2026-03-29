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
      self.nixosModules.hosts--nixsun
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
    ];
  };
}
