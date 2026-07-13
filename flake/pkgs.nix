{
  inputs,
  self,
  ...
}: {
  # Single source of truth — consumed here AND by builders/hosts.nix's
  # mkHost, so perSystem pkgs and every per-host pkgs set stay in sync.
  flake.lib.overlays = [
    self.overlays.unstable-packages
    self.overlays.stable-packages
    self.overlays.additions
    self.overlays.modifications
  ];

  flake.lib.nixpkgsConfig = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
  };

  perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config = self.lib.nixpkgsConfig;
      overlays = self.lib.overlays;
    };
  };
}
