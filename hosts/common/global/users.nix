{self, ...}: {
  flake.nixosModules.hosts--c-glo--users = {...}: {
    imports = [
      # Paths to other modules.
      # Compose this module out of smaller ones.
      ./_users
    ];
  };
}
