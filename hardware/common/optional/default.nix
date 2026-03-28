{
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./nvidia.nix
    ./driver-nvidia.nix
    ./drives.nix
    ./drives-additional.nix
  ];
}
