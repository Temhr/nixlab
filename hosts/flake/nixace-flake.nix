# Flake-parts wrapper for nixace.
# The feature manifest (nixace.nix) is unchanged and stays in place.
{self, ...}: {
  flake.nixosModules.hosts--nixace = {...}: {
    networking.hostName = "nixace";
    imports = [(import ../nixace.nix)];
  };

  flake.nixosConfigurations.nixace = self.lib.mkHost {
    modules = [
      self.nixosModules.hw--common-global
      self.nixosModules.hw--common-optional--driver-nvidia
      self.nixosModules.hw--zb17g4-p5
      self.nixosModules.hosts--common-global
      self.nixosModules.hosts--common-optional
      self.nixosModules.sys--cachix
      self.nixosModules.hosts--nixace
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
