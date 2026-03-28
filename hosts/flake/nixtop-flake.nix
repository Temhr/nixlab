{self, ...}: {
  flake.nixosModules.hosts--nixtop = {...}: {
    networking.hostName = "nixtop";
    imports = [(import ../nixtop.nix)];
  };

  flake.nixosConfigurations.nixtop = self.lib.mkHost {
    modules = [
      self.nixosModules.hw--common-global
      self.nixosModules.hw--common-optional
      self.nixosModules.hw--zb17g2-k5
      self.nixosModules.hosts--common-global
      self.nixosModules.hosts--common-optional
      self.nixosModules.sys--cachix
      self.nixosModules.hosts--nixtop
      self.nixosModules.grafana-nixlab
      self.nixosModules.secrets--grafana
      self.nixosModules.loki-nixlab
      self.nixosModules.prometheus-nixlab
      self.nixosModules.waydroid-nixlab
    ];
  };
}
