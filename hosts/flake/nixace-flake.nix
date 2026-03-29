{self, ...}: {
  flake.nixosModules.hosts--nixace = {...}: {
    networking.hostName = "nixace";
    imports = [(import ../nixace.nix)];
  };

  flake.nixosConfigurations.nixace = self.lib.mkHost {
    modules = [
      self.nixosModules.hw--c-global
      self.nixosModules.hw--c-optional--driver-nvidia
      self.nixosModules.hw--zb17g4-p5
      self.nixosModules.hosts--nixace
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
      self.nixosModules.svc--bookstack-nixlab
      self.nixosModules.secrets--bookstack
      self.nixosModules.svc--comfyui-p5000
      self.nixosModules.svc--comfyui-extensions
      self.nixosModules.svc--comfyui-models
      self.nixosModules.svc--grafana-nixlab
      self.nixosModules.secrets--grafana
      self.nixosModules.svc--loki-nixlab
      self.nixosModules.svc--ollama-p5000
      self.nixosModules.svc--prometheus-nixlab
    ];
  };
}
