{inputs, ...}: {
  flake.overlays = {
    additions = final: _prev: import ../pkgs final.pkgs;

    modifications = final: prev: let
      ollamaOverlay =
        import ./_ollama-p5000.nix {
          nixpkgs-ollama = inputs.nixpkgs-ollama;
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
        config = {
          allowUnfree = true;
          cudaSupport = true;
          cudaCapabilities = ["6.1"];
          cudaForwardCompat = false;
        };
      };
    };

    stable-packages = final: _prev: {
      stable = import inputs.nixpkgs-stable {
        system = final.stdenv.hostPlatform.system;
        config = {
          allowUnfree = true;
          cudaSupport = true;
          cudaCapabilities = ["6.1"];
          cudaForwardCompat = false;
        };
      };
    };
  };
}
