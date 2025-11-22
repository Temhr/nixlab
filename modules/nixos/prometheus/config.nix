# ============================================================================
# FILE: prometheus/config.nix
# ============================================================================
{ config, lib, pkgs, ... }:

let
  cfg = config.services.prometheus-custom;

  # Import specialized configurations
  scrapeConfigs = import ./scrape-configs.nix { inherit config lib; };
  prometheusService = import ./services/prometheus.nix { inherit config lib pkgs; };
  nodeExporterService = import ./exporters/node.nix { inherit config lib pkgs; };
  maintenanceExporters = import ./exporters/maintenance.nix { inherit config lib pkgs; };
  nginxConfig = import ./extras/nginx.nix { inherit config lib; };
in
{
  # Directory setup
  systemd.tmpfiles.rules = [
    "d ${cfg.dataDir} 0770 prometheus prometheus -"
  ] ++ lib.optionals cfg.maintenance.enable [
    "d /var/lib/node_exporter 0755 prometheus prometheus -"
  ];

  # User configuration
  users.users.prometheus = {
    isSystemUser = true;
    group = "prometheus";
    home = cfg.dataDir;
    description = "Prometheus service user";
    extraGroups = lib.optional
      (cfg.maintenance.enable && cfg.maintenance.exporters.smartctl.enable)
      "disk";
  };

  users.groups.prometheus = {};
  users.users.temhr.extraGroups = [ "prometheus" ];

  # Import service configurations
  systemd.services = {
    prometheus = prometheusService;
    prometheus-node-exporter = lib.mkIf cfg.enableNodeExporter nodeExporterService;
  } // maintenanceExporters.services;

  # Import exporter configurations
  services.prometheus.exporters = maintenanceExporters.exporters;

  # Nginx configuration
  services.nginx = nginxConfig;

  # Firewall configuration
  networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
    lib.optionals (cfg.domain == null) [ cfg.port ]
    ++ lib.optionals (cfg.domain != null) [ 80 443 ]
  );
}
