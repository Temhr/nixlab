{self, ...}: {
  flake.nixosModules.nixzen = {...}: {
    networking.hostName = "nixzen";
    imports = [
      (import ./nixzen.nix)
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
      self.nixosModules.bookstack-nixlab
      self.nixosModules.secrets-bookstack
      self.nixosModules.comfyui-p5000
      self.nixosModules.comfyui-extensions
      self.nixosModules.comfyui-models
      self.nixosModules.grafana-nixlab
      self.nixosModules.secrets-grafana
      self.nixosModules.homepage-nixlab
      self.nixosModules.loki-nixlab
      self.nixosModules.ollama-cpu
      self.nixosModules.ollama-p5000
      self.nixosModules.prometheus-nixlab
      self.nixosModules.glance-nixlab
      self.nixosModules.gotosocial-nixlab
      self.nixosModules.home-assistant-nixlab
      self.nixosModules.node-red-nixlab
      self.nixosModules.syncthing-nixlab
      self.nixosModules.waydroid-nixlab
      self.nixosModules.wiki-js-custom
      self.nixosModules.zola-custom
    ];
  };
}
