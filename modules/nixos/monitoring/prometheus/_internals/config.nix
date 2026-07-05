# ============================================================================
# FILE: prometheus/config.nix
# ============================================================================
{
  config,
  lib,
  pkgs,
  nixlabLib,
  ...
}: let
  cfg = config.services.prometheus-nixlab;

  # Import specialized configurations
  prometheusService = import ./services/prometheus.nix {inherit config lib pkgs nixlabLib;};
  nodeExporterService = import ./exporters/node.nix {inherit config lib pkgs nixlabLib;};
  maintenanceExporters = import ./exporters/maintenance.nix {inherit config lib pkgs;};
  nginxConfig = import ./extras/nginx.nix {inherit config lib nixlabLib;};
in {
  # Directory setup
  systemd.tmpfiles.rules =
    [
      "d ${cfg.dataDir} 0770 prometheus prometheus -"
    ]
    ++ lib.optionals cfg.maintenance.enable [
      "d /var/lib/node_exporter 0755 prometheus prometheus -"
    ];

  # User configuration
  users.users = lib.mkMerge (
    [
      {
        prometheus = {
          isSystemUser = true;
          group = "prometheus";
          home = cfg.dataDir;
          description = "Prometheus service user";
          extraGroups =
            lib.optional
            (cfg.maintenance.enable && cfg.maintenance.exporters.smartctl.enable)
            "disk";
        };
      }
    ]
    ++ lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
    (map (u: {${u} = {extraGroups = ["prometheus"];};})
      ([config.nixlab.mainUser] ++ cfg.extraUsers))
  );

  users.groups.prometheus = {};

  # Import service configurations
  systemd.services =
    {
      prometheus = prometheusService;
      prometheus-node-exporter = lib.mkIf cfg.enableNodeExporter nodeExporterService;
    }
    // maintenanceExporters.services;

  # Import exporter configurations
  services.prometheus.exporters = maintenanceExporters.exporters;

  # Nginx configuration
  services.nginx = nginxConfig;

  # Firewall configuration
  networking.firewall.allowedTCPPorts =
    lib.mkIf cfg.openFirewall
    (nixlabLib.mkFirewallPorts {
      inherit (cfg) domain listenAddress;
      servicePort = cfg.port;
    });
}
