{self, ...}: {
  flake.nixosModules.servc--prometheus-nixlab = {
    config,
    lib,
    pkgs,
    nixlabLib,
    ...
  }: let
    cfg = config.services.prometheus-nixlab;

    options = import ./_internals/options.nix {inherit lib pkgs;};
    prometheusConfig = import ./_internals/config.nix {inherit config lib pkgs nixlabLib;};
  in {
    imports = [
      self.nixosModules.systm--ports-prometheus
      self.nixosModules.systm--host-exporters-nixlab
    ];

    options.services.prometheus-nixlab = options;

    config = lib.mkIf cfg.enable (lib.mkMerge [
      prometheusConfig
      # Automatic recovery when Prometheus crashes on a corrupt WAL.
      (nixlabLib.mkWalSelfHeal {
        inherit pkgs;
        unit = "prometheus";
        walDir = "${cfg.dataDir}/data/wal";
        user = "prometheus";
        group = "prometheus";
      })
    ]);
  };

  # Exposed for flake/ci/monitoring-checks.nix, which consumes them by name.
  flake.lib.prometheusRendered = import ./_internals/rendered.nix;
  flake.lib.prometheusMaintenanceAlerts = import ./_internals/maintenance-alerts.nix;
}
