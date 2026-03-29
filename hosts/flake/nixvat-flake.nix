{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.hosts--nixvat = {...}: {
    networking.hostName = "nixvat";
    imports = [
      (import ../nixvat.nix)
      "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
    ];
  };

  flake.nixosConfigurations.nixvat = self.lib.mkHost {
    modules = [
      self.nixosModules.hw--common-global
      self.nixosModules.hw--common-optional--driver-nvidia
      self.nixosModules.hw--zb17g1-k3
      self.nixosModules.hosts--common-global
      self.nixosModules.hosts--common-optional
      self.nixosModules.sys--cachix
      self.nixosModules.hosts--nixvat
      self.nixosModules.svc--bookstack-nixlab
      self.nixosModules.secrets--bookstack
      self.nixosModules.svc--comfyui-p5000
      self.nixosModules.svc--comfyui-extensions
      self.nixosModules.svc--comfyui-models
      self.nixosModules.svc--grafana-nixlab
      self.nixosModules.secrets--grafana
      self.nixosModules.svc--homepage-nixlab
      self.nixosModules.svc--loki-nixlab
      self.nixosModules.svc--ollama-cpu
      self.nixosModules.svc--prometheus-nixlab
      self.nixosModules.svc--glance-nixlab
      self.nixosModules.svc--gotosocial-nixlab
      self.nixosModules.svc--home-assistant-nixlab
      self.nixosModules.svc--node-red-nixlab
      self.nixosModules.svc--syncthing-nixlab
      self.nixosModules.svc--wiki-js-nixlab
      self.nixosModules.svc--zola-nixlab
    ];
  };
}
