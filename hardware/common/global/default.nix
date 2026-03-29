{...}: {
  flake.nixosModules.hw--c-global = {
    imports = [
      # Paths to other modules.
      # Compose this module out of smaller ones.
      ./_internals/drives.nix
      ./_internals/drives-additional.nix
      ./_internals/hardware-configuration.nix
    ];
  };
}
