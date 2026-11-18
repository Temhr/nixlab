{self, ...}: {
  flake.nixosModules.stack--observability-nixlab = {
    config,
    lib,
    ...
  }: let
    registry = self.lib.serviceRegistry {inherit config;};
    registryTcpTargets =
      lib.mapAttrsToList (_: e: "127.0.0.1:${toString e.port}")
      (lib.filterAttrs (k: _: registry.enabled.${k} or false) (registry.endpoints or {}));
  in {
    imports = [
      self.nixosModules.stack--observability
      self.nixosModules.nsops--alertmanager
      self.nixosModules.nsops--grafana
    ];

    # S4: same list the stack used to compute internally.
    services.nixlab-observability.probes.tcpTargets = lib.mkDefault registryTcpTargets;

    # S5: encrypted files stay in nixlab.
    services.alertmanager-nixlab.secretsFile = lib.mkDefault ../sops/alertmanager.env;
    services.grafana-nixlab.secretsFile = lib.mkDefault ../sops/grafana.yaml;
  };
}
