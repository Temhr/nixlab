{...}: {
  flake.nixosModules.hosts--common-global = import ../.;
}
