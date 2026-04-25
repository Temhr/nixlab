{inputs, ...}: {
  flake.overlays = {
    additions = final: _prev: import ../pkgs final.pkgs;

    modifications = final: prev: let
      ollamaOverlay =
        import ./_ollama-p5000.nix {
          nixpkgs-ollama = inputs.nixpkgs-ollama; # Changed from unstableNixpkgs/stableNixpkgs
          system = final.stdenv.hostPlatform.system;
        }
        final
        prev;
      # Remove the open-webui overlay since it's now in _ollama-p5000.nix
      comfyuiOverlay = import ./_comfyui-p5000.nix final prev;
    in
      ollamaOverlay // comfyuiOverlay; # Removed open-webuiOverlay

    # Keep these if other parts of your config use pkgs.unstable / pkgs.stable
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
