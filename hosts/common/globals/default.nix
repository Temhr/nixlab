{
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./audio.nix
    ./locale.nix
    ./open-ssh.nix
    ./users.nix
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
