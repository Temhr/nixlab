{self, ...}: {
  flake.nixosModules.nixtop = {...}: {
    networking.hostName = "nixtop";
    imports = [(import ../nixtop.nix)];
  };

  flake.nixosConfigurations.nixtop = self.lib.mkHost {
    modules = [
      self.nixosModules.hw-common-global
      self.nixosModules.hw-common-optional
      self.nixosModules.hw-zb17g2-k5
      self.nixosModules.hosts-global
      self.nixosModules.hosts-optional
      self.nixosModules.cachix
      self.nixosModules.nixtop
      self.nixosModules.grafana-nixlab
      self.nixosModules.secrets-grafana
      self.nixosModules.loki-nixlab
      self.nixosModules.prometheus-nixlab
      self.nixosModules.waydroid-nixlab
    ];
  };
}
