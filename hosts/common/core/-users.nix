{self, ...}: {
  flake.nixosModules.hosts--core--users = {...}: {
    imports = [
      # Paths to other modules.
      # Compose this module out of smaller ones.
      ./_users
    ];
  };
}
