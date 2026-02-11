{ ... }: {
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./users
    ./audio.nix
    ./auto-backup-home.nix
    #./auto-display-manager-startup-check.nix
    ./auto-nix-gc.nix
    ./auto-nixos-upgrade.nix
    ./bluetooth.nix
    ./boot-loader.nix
    ./display-manager.nix
    ./firefox.nix
    ./flatpak.nix
    ./journald.nix
    ./lid.nix
    ./locale.nix
    ./network.nix
    ./nix.nix
    ./nixpkgs.nix
    ./open-ssh.nix
    ./power-management.nix
    ./system.nix
    ./utilities.nix
  ];
  options = {
    # Option declarations.
    # Declare what settings a user of this module can set.
    # Usually this includes a global "enable" option which defaults to false.
  };
  config = {
    # Option definitions.
    # Define what other settings, services and resources should be active.
    # Usually these depend on whether a user of this module chose to "enable" it
    # using the "option" above.
    # Options for modules imported in "imports" can be set here.
  };
}
