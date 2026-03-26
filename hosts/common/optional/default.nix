{...}: {
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./development.nix
    ./education.nix
    ./games.nix
    ./graphical-shells.nix
    ./ignore-lid.nix
    ./media.nix
    ./observability.nix
    ./productivity.nix
    ./virtualizations.nix
  ];
}
