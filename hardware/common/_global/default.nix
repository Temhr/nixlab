{...}: {
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./mounts.nix
    ./hardware-configuration.nix
  ];
}
