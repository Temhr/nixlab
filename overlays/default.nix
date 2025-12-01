# This file imports and combines all overlays
{inputs, ...}: {
  # Custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # Import modular overlays
  modifications = final: prev:
    let
      # Load each overlay module
      ollamaOverlay = import ./ollama-p5000.nix final prev;
      comfyuiOverlay = import ./comfyu-p5000.nix final prev;
    in
      ollamaOverlay // comfyuiOverlay;

  # Stable nixpkgs overlay
  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
      config.cudaSupport = true;
    };
  };
}
