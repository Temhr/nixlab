{...}: {
  flake.nixosModules.hw--c-global = {
    imports = [
      # Paths to other modules.
      # Compose this module out of smaller ones.
      ./_global
    ];
  };
}
