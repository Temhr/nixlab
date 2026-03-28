{...}: {
  flake.nixosModules.secrets--grafana = import ../secrets-grafana.nix;
}
