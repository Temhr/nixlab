# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # Use stable Ollama for better GPU compatibility
    ollama = final.stable.ollama;

    # Alternative: Use stable Ollama but keep it updated
    # ollama = prev.ollama.overrideAttrs (oldAttrs: {
    #   src = final.stable.ollama.src;
    #   version = final.stable.ollama.version;
    # });

    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
  };

  # When applied, the stable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.stable'
  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
      config.cudaSupport = true;  # Enable CUDA support in stable packages
    };
  };
}
