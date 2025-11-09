{
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./bookstack.nix
    ./development.nix
    ./education.nix
    ./games.nix
    ./homepage-dashboard.nix
    ./productivity.nix
    ./media.nix
    ./virtualizations.nix
    ./wiki-js.nix
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
