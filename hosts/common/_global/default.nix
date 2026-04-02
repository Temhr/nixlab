{...}: {
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./users
    ./audio.nix
    ./auto-backup-home.nix
    ./auto-nix-gc.nix
    ./auto-nixos-upgrade.nix
    ./bluetooth.nix
    ./boot-loader.nix
    ./display-manager.nix
    ./firefox.nix
    ./flatpak.nix
    ./journald.nix
    ./locale.nix
    ./network.nix
    ./nginx.nix
    ./nix.nix
    ./nixpkgs.nix
    ./open-ssh.nix
    ./power-management.nix
    ./system.nix
    ./utilities.nix
  ];
}
