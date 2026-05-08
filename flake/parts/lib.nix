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

  # Build common modules with a specific nixpkgs input
  mkCommonModules = nixpkgsSource: [
    inputs.sops-nix.nixosModules.sops
    self.nixosModules.systm--home-manager-config
    {nixpkgs.overlays = allOverlays;}
  ];

  mkHost = {
    name,
    modules,
  }: let
    meta = hostsMeta.${name};
    nixpkgsSource = inputs.${meta.nixpkgsInput}; # Select the nixpkgs input based on meta
  in
    assert lib.assertMsg
    (builtins.hasAttr name hostsMeta)
    "mkHost: no hostsMeta entry found for '${name}' — add it to the hostsMeta attrset in flake/parts/lib.nix";
    assert lib.assertMsg
    (builtins.hasAttr meta.nixpkgsInput inputs)
    "mkHost: nixpkgsInput '${meta.nixpkgsInput}' not found in flake inputs for host '${name}'";
      lib.nixosSystem {
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
          (mkCommonModules nixpkgsSource)
          ++ modules
          ++ [
            {networking.hostName = name;}
            # Conditionally add hostId if it exists in meta
            (lib.mkIf (meta.hostId != null) {
              networking.hostId = meta.hostId;
            })
            # Override nixpkgs to use the selected input
            {
              nixpkgs.pkgs = lib.mkForce (import nixpkgsSource {
                inherit (meta) system;
                config.allowUnfree = true;
                overlays = allOverlays;
              });
            }
          ];
      };
in {
  flake.lib = {inherit mkHost hostsMeta;};
}
