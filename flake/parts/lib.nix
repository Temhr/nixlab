# flake/parts/lib.nix
{
  self,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs) lib;
  hostsMeta = import ./_hosts-meta.nix;

  allOverlays = [
    self.overlays.unstable-packages
    self.overlays.stable-packages
    self.overlays.additions
    self.overlays.modifications
  ];

  commonModules = [
    inputs.sops-nix.nixosModules.sops
    self.nixosModules.systm--home-manager-config
    {nixpkgs.overlays = allOverlays;}
  ];

  mkHost = {
    name,
    modules,
  }: let
    meta = hostsMeta.${name};
  in
    assert lib.assertMsg
    (builtins.hasAttr name hostsMeta)
    "mkHost: no hostsMeta entry found for '${name}' — add it to the hostsMeta attrset in flake/parts/lib.nix";
      lib.nixosSystem {
        system = meta.system;
        specialArgs = {
          inherit inputs self;
          outputs = self;
          flakePath = self;
          allHosts = hostsMeta;
          hostMeta = meta;
          self' =
            self.packages.${meta.system}
            // {
              packages = self.packages.${meta.system};
              devShells = self.devShells.${meta.system};
              apps = self.apps.${meta.system} or {};
            };
        };
        modules =
          commonModules
          ++ modules
          ++ [
            {networking.hostName = name;}
          ];
      };
in {
  flake.lib = {inherit mkHost hostsMeta;};
}
