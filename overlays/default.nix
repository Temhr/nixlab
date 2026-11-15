{inputs, ...}: let
  # CUDA 13 dropped Pascal (sm_61). Force CUDA 12.9 inside the extra nixpkgs
  # instances that are configured for the P5000.
  cuda12Overlay = f: _p: {
    cudaPackages = f.cudaPackages_12_9 or f.cudaPackages_12;
  };
in {
  flake.overlays = {
    additions = final: _prev: import ../pkgs final.pkgs;

    modifications = final: prev: let
      ollamaOverlay =
        import ./_ollama-p5000.nix {
          nixpkgs-ollama = inputs.nixpkgs-ollama;
          nixpkgs-open-webui = inputs.nixpkgs-open-webui;
          nixpkgs-stable = inputs.nixpkgs-stable;
          system = final.stdenv.hostPlatform.system;
        }
        final
        prev;

      pytorchOverlay = import ./_pytorch-p5000.nix final prev;

      comfyuiOverlay = import ./_comfyui-p5000.nix final prev;
    in
      ollamaOverlay // pytorchOverlay // comfyuiOverlay;

    unstable-packages = final: _prev: {
      unstable = import inputs.nixpkgs-unstable {
        system = final.stdenv.hostPlatform.system;
        overlays = [cuda12Overlay];
        config.allowUnfree = true;
        config.cudaSupport = true;
        config.cudaCapabilities = ["6.1"];
      };
    };

    stable-packages = final: _prev: {
      stable = import inputs.nixpkgs-stable {
        system = final.stdenv.hostPlatform.system;
        overlays = [cuda12Overlay];
        config.allowUnfree = true;
        config.cudaSupport = true;
        config.cudaCapabilities = ["6.1"];
      };
    };
  };
}
