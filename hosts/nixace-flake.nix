# Flake-parts wrapper for nixace.
# The feature manifest (nixace.nix) is unchanged and stays in place.
{self, ...}: {
  flake.nixosModules.nixace = {...}: {
    networking.hostName = "nixace";
    imports = [(import ./nixace.nix)];
  };

  flake.nixosConfigurations.nixace = self.lib.mkHost {
    modules = [
      self.nixosModules.hw-common-global
      self.nixosModules.hw-common-optional
      self.nixosModules.hw-zb17g4-p5
      self.nixosModules.hosts-global
      self.nixosModules.hosts-optional
      self.nixosModules.cachix
      self.nixosModules.nixace
      self.nixosModules.bookstack-nixlab
      self.nixosModules.secrets-bookstack
      self.nixosModules.comfyui-p5000
      self.nixosModules.comfyui-extensions
      self.nixosModules.comfyui-models
      self.nixosModules.grafana-nixlab
      self.nixosModules.secrets-grafana
      self.nixosModules.homepage-nixlab
      self.nixosModules.loki-custom
      self.nixosModules.ollama-cpu
      self.nixosModules.ollama-p5000
      self.nixosModules.prometheus-custom
      self.nixosModules.glance-custom
      self.nixosModules.gotosocial-custom
      self.nixosModules.home-assistant-custom
      self.nixosModules.node-red-custom
      self.nixosModules.syncthing-custom
      self.nixosModules.waydroid-custom
      self.nixosModules.wiki-js-custom
      self.nixosModules.zola-custom
    ];
  };
}
