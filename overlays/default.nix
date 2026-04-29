# This file imports and combines all overlays
{inputs, ...}: {
  flake.overlays = {
    additions = final: _prev: import ../pkgs final.pkgs;

    modifications = final: prev: let
      ollamaOverlay =
        import ./_ollama-p5000.nix {
          unstableNixpkgs = inputs.nixpkgs-unstable;
          stableNixpkgs = inputs.nixpkgs-stable;
          system = final.stdenv.hostPlatform.system;
        }
        final
        prev;
      open-webuiOverlay = import ./_open-webui.nix final prev;
      comfyuiOverlay = import ./_comfyui-p5000.nix final prev;
    in
      ollamaOverlay // open-webuiOverlay // comfyuiOverlay;

    # The separate unstable/stable overlays are now only needed if other
    # parts of your config use pkgs.unstable / pkgs.stable directly.
    # Keep them if so, remove if not.
    unstable-packages = final: _prev: {
      unstable = import inputs.nixpkgs-unstable {
        system = final.stdenv.hostPlatform.system;
        config.allowUnfree = true;
        config.cudaSupport = true;
      };
    };
    stable-packages = final: _prev: {
      stable = import inputs.nixpkgs-stable {
        system = final.stdenv.hostPlatform.system;
        config.allowUnfree = true;
        config.cudaSupport = true;
      };
    };
  };
}
