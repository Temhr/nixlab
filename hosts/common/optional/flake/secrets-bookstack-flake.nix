{...}: {
  flake.nixosModules.secrets-bookstack = import ../secrets-bookstack.nix;
}
