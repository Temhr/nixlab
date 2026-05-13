{...}: {
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./users
    ./audio.nix
    ./auto-backup-home.nix
    ./auto-git-pull.nix
    ./auto-nix-gc.nix
    ./auto-nixos-upgrade.nix
    ./auto-ping-watchdog.nix
    ./auto-update-flake.nix
    ./bluetooth.nix
    ./boot-loader.nix
    ./display-manager.nix
    ./firefox.nix
    ./flatpak.nix
    ./journald.nix
    ./locale.nix
    ./nginx.nix
    ./nix.nix
    ./nixpkgs.nix
    ./open-ssh.nix
    ./power-management.nix
    ./sops.nix
    ./system.nix
    ./utilities.nix
  ];
}
