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

  mkCommonModules = [
    inputs.sops-nix.nixosModules.sops
    self.nixosModules.systm--home-manager-config
    {nixpkgs.overlays = allOverlays;}
  ];

  mkHost = {
    name,
    modules,
  }: let
    meta = hostsMeta.${name};
    nixpkgsSource = inputs.${meta.nixpkgsInput};
    hostLib = nixpkgsSource.lib;
  in
    assert hostLib.assertMsg
    (builtins.hasAttr name hostsMeta)
    "mkHost: no hostsMeta entry found for '${name}' — add it to the hostsMeta attrset in flake/parts/lib.nix";
    assert hostLib.assertMsg
    (builtins.hasAttr meta.nixpkgsInput inputs)
    "mkHost: nixpkgsInput '${meta.nixpkgsInput}' not found in flake inputs for host '${name}'";
      hostLib.nixosSystem {
        system = meta.system;
        specialArgs = {
          inherit inputs self;
          outputs = self;
          flakePath = self;
          allHosts = hostsMeta;
          hostMeta = meta;
          # Pass the selected nixpkgs for reference
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
          mkCommonModules
          ++ modules
          ++ [
            {networking.hostName = name;}
            # Conditionally add hostId if it exists in meta
            (lib.mkIf (meta.hostId != null) {
              networking.hostId = meta.hostId;
            })
            # Override nixpkgs source while preserving config from modules
            {
              nixpkgs.pkgs = lib.mkForce (import nixpkgsSource {
                inherit (meta) system;
                config = {
                  allowUnfree = true;
                  # Nvidia license acceptance (if nvidia driver is enabled)
                  nvidia.acceptLicense = true;
                };
                overlays = allOverlays;
              });
            }
          ];
      };
in {
  flake.lib = {inherit mkHost hostsMeta;};
}
