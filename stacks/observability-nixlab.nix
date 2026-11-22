{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.stack--observability-nixlab = {
    config,
    lib,
    hostMeta ? {},
    ...
  }: let
    obs = inputs.observability.nixosModules;
    registry = self.lib.serviceRegistry {inherit config;};
    registryTcpTargets =
      lib.mapAttrsToList (_: e: "127.0.0.1:${toString e.port}")
      (lib.filterAttrs (k: _: registry.enabled.${k} or false) (registry.endpoints or {}));
    mainUsers = let u = config.nixlab.mainUser or ""; in lib.optional (u != "") u;
  in {
    imports = [obs.stack--observability obs.nsops--observability-alertmanager obs.nsops--observability-grafana];

    services.observability = {
      publicHost = lib.mkDefault (hostMeta.address or null);
      probes.gateway = lib.mkDefault (hostMeta.gateway or null);
      probes.tcpTargets = lib.mkDefault registryTcpTargets;
      integrations.nvidia.enable = lib.mkDefault (builtins.elem "nvidia" config.services.xserver.videoDrivers);
    };
    services.observability-prometheus.maintenance.alerts.features.zfsMembers = lib.mkDefault true;
    services.observability-grafana.timersRegex = lib.mkDefault "nixos-upgrade.timer|flake-update.timer|backup-home.timer|nixlab-gpull.timer|nix-gc.timer";

    services.observability-alertmanager.secretsFile = lib.mkDefault ../sops/alertmanager.env;
    services.observability-grafana.secretsFile = lib.mkDefault ../sops/grafana.yaml;

    # Plain assignment on purpose (lists merge; mkDefault would be dropped if a host set its own).
    services.observability-loki.extraUsers = mainUsers;
    services.observability-grafana.extraUsers = mainUsers;
    services.observability-alloy.extraUsers = mainUsers;
    services.observability-ntfy.extraUsers = mainUsers;
    services.observability-prometheus.extraUsers = mainUsers;
  };
}
