# This file imports and combines all overlays
{inputs, ...}: {
  flake.overlays = {
    additions = final: _prev: import ../pkgs final.pkgs;
    modifications = final: prev: let
      ollamaOverlay = import ./ollama-p5000.nix final prev;
      open-webuiOverlay = import ./open-webui.nix final prev;
      comfyuiOverlay = import ./comfyui-p5000.nix final prev;
    in
      ollamaOverlay // open-webuiOverlay // comfyuiOverlay;
    ollama-packages = final: _prev: {
      ollamaPkgs = import inputs.nixpkgs-ollama {
        system = final.stdenv.hostPlatform.system;
        config.allowUnfree = true;
        config.cudaSupport = true;
      };
    };
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
