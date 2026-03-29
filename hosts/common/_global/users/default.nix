{...}: {
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./home-manager.nix
    ./users.nix
    ./main-user.nix
  ];
}
