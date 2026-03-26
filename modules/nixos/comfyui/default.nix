{...}: {
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./comfyui-extensions.nix
    ./comfyui-models.nix
    ./comfyui-p5000.nix
  ];
}
