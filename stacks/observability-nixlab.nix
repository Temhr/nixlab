{self, ...}: {
  flake.nixosModules.stack--observability-nixlab = {
    config,
    lib,
    hostMeta ? {},
    ...
  }: let
    registry = self.lib.serviceRegistry {inherit config;};
    registryTcpTargets =
      lib.mapAttrsToList (_: e: "127.0.0.1:${toString e.port}")
      (lib.filterAttrs (k: _: registry.enabled.${k} or false) (registry.endpoints or {}));
    mainUsers = let u = config.nixlab.mainUser or ""; in lib.optional (u != "") u;
  in {
    imports = [
      self.nixosModules.stack--observability
      self.nixosModules.nsops--alertmanager
      self.nixosModules.nsops--grafana
    ];

    # Old option names: they still work in 0.3 through compat aliases (Stage B renames them).
    services.nixlab-observability = {
      publicHost = lib.mkDefault (hostMeta.address or null);
      probes.gateway = lib.mkDefault (hostMeta.gateway or null);
      probes.tcpTargets = lib.mkDefault registryTcpTargets;
    };
    services.alertmanager-nixlab.secretsFile = lib.mkDefault ../sops/alertmanager.env;
    services.grafana-nixlab.secretsFile = lib.mkDefault ../sops/grafana.yaml;
    # Plain assignment on purpose: lists merge; mkDefault would be dropped if a host set its own.
    services.loki-nixlab.extraUsers = mainUsers;
    services.grafana-nixlab.extraUsers = mainUsers;
    services.alloy-nixlab.extraUsers = mainUsers;
    services.ntfy-nixlab.extraUsers = mainUsers;
    services.prometheus-nixlab.extraUsers = mainUsers;

    # New in 0.3: these options have no old spelling, so they use their new names even in Stage A.
    # They keep behaviour nixlab relied on before the extraction (Part 8).
    services.observability.integrations.nvidia.enable = lib.mkDefault true;
    services.observability-prometheus.maintenance.alerts.features.zfsMembers = lib.mkDefault true;
    services.observability-grafana.timersRegex = lib.mkDefault "nixos-upgrade.timer|flake-update.timer|backup-home.timer|nixlab-gpull.timer|nix-gc.timer";
  };
}
