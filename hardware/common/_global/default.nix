{...}: {
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./drives.nix
    ./drives-additional.nix
    ./hardware-configuration.nix
  ];
}
