{
  self,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs) lib;
  hostsMeta = self.lib.hostsMeta;
  nixlabLib = self.lib.nixlabLib;

  mkCommonModules = [
    inputs.sops-nix.nixosModules.sops
    self.nixosModules.hosts--core--home-manager-config
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    }
  ];
in {
  flake.lib.mkHost = {
    name,
    modules,
  }:
    assert lib.assertMsg
    (builtins.hasAttr name hostsMeta)
    "mkHost: no hostsMeta entry found for '${name}'"; let
      meta = hostsMeta.${name};
    in
      assert lib.assertMsg
      (builtins.hasAttr meta.nixpkgsInput inputs)
      "mkHost: nixpkgsInput '${meta.nixpkgsInput}' not found in flake inputs for host '${name}'"; let
        nixpkgsSource = inputs.${meta.nixpkgsInput};
        hostLib = nixpkgsSource.lib;
        hostPkgs = import nixpkgsSource {
          inherit (meta) system;
          config = self.lib.nixpkgsConfig;
          overlays = self.lib.overlays;
        };
      in
        hostLib.nixosSystem {
          specialArgs = {
            inherit inputs self;
            inherit nixlabLib;
            flakePath = self;
            allHosts = hostsMeta;
            hostMeta = meta;
            nixpkgsSource = nixpkgsSource;
            self' = {
              packages = self.packages.${meta.system};
              devShells = self.devShells.${meta.system};
              apps = self.apps.${meta.system} or {};
            };
          };
          modules =
            mkCommonModules
            ++ modules
            ++ [
              {networking.hostName = name;}
              (hostLib.mkIf (meta.hostId != null) {
                networking.hostId = meta.hostId;
              })
              {
                imports = ["${nixpkgsSource}/nixos/modules/misc/nixpkgs/read-only.nix"];
                nixpkgs.pkgs = hostPkgs;
              }
              {
                nix.registry.nixpkgs = hostLib.mkForce {
                  flake = nixpkgsSource;
                };
              }
            ];
        };
}
