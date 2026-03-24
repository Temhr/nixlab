{ inputs, self, ... }: {

  perSystem = { system, ... }:
    let
      allOverlays = [
        self.overlays.unstable-packages
        self.overlays.stable-packages
        self.overlays.ollama-packages
        self.overlays.additions
        self.overlays.modifications
      ];
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = allOverlays;
      };
    in {
      devShells = import ../../shells { inherit pkgs; };
    };

}
