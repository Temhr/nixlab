{
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./config-fastfetch.nix
    ./config-folders.nix
    ./config-git.nix
    ./config-virt-manager.nix
    ./ephemeral-apps.nix
    ./system.nix
    ./utilities.nix
  ];
}
