# Configures the default pkgs instance for all perSystem blocks.
# Sets allowUnfree = true so devShells and packages can use unfree
# packages (e.g. nvidia drivers in mesa/repast GPU shells) without
# needing per-shell workarounds.
{
  inputs,
  self,
  ...
}: {
  perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        self.overlays.unstable-packages
        self.overlays.stable-packages
        self.overlays.ollama-packages
        self.overlays.additions
        self.overlays.modifications
      ];
    };
  };
}
