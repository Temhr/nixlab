{
  self,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs) lib;
  hostsMeta = import ./_hosts-meta.nix { inherit lib; };
  nixlabLib = import ./_nixos-lib.nix { inherit lib; };

  allOverlays = [
    self.overlays.unstable-packages
    self.overlays.stable-packages
    self.overlays.additions
    self.overlays.modifications
  ];

  mkCommonModules = hostPkgs: [
    inputs.sops-nix.nixosModules.sops
    self.nixosModules.hosts--core--home-manager-config
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    }
  ];

  mkHost = {
    name,
    modules,
  }: let
    meta = hostsMeta.${name};
    nixpkgsSource = inputs.${meta.nixpkgsInput};
    hostLib = nixpkgsSource.lib;
    hostPkgs = import nixpkgsSource {
      inherit (meta) system;
      config = {
        allowUnfree = true;
        nvidia.acceptLicense = true;
      };
      overlays = allOverlays;
    };
  in
    assert hostLib.assertMsg
    (builtins.hasAttr name hostsMeta)
    "mkHost: no hostsMeta entry found for '${name}'";
    assert hostLib.assertMsg
    (builtins.hasAttr meta.nixpkgsInput inputs)
    "mkHost: nixpkgsInput '${meta.nixpkgsInput}' not found in flake inputs for host '${name}'";
      hostLib.nixosSystem {
        specialArgs = {
          inherit inputs self;
          inherit nixlabLib;
          outputs = self;
          flakePath = self;
          allHosts = hostsMeta;
          hostMeta = meta;
          nixpkgsSource = nixpkgsSource;
          self' =
            self.packages.${meta.system}
            // {
              packages = self.packages.${meta.system};
              devShells = self.devShells.${meta.system};
              apps = self.apps.${meta.system} or {};
            };
        };
        modules =
          (mkCommonModules hostPkgs)
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
in {
  flake.lib = { inherit mkHost hostsMeta nixlabLib; };
}
