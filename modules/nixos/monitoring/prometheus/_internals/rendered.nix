# Rendered Prometheus configuration and rule groups.
# Imported by services/prometheus.nix (to write the files on the host)
# and registered as self.lib.prometheusRendered by prometheus/default.nix
# (so flake/ci/monitoring-checks.nix can validate them at build time).
{
  config,
  lib,
}: let
  cfg = config.services.prometheus-nixlab;
  scrapeConfigs = import ./scrape-configs.nix {inherit config lib;};

  alertRulesConfig = import ./alerts.nix;
  alertFeatures =
    cfg.maintenance.alerts.features
    // {
      backup = cfg.maintenance.exporters.backup.enable;
      dns = cfg.maintenance.exporters.blackbox.enable && cfg.maintenance.exporters.blackbox.dnsTargets != [];
    };
  maintenanceAlertRules =
    if cfg.maintenance.enable
    then import ./maintenance-alerts.nix {features = alertFeatures;}
    else {groups = [];};
in {
  rules = {
    groups = alertRulesConfig.groups ++ maintenanceAlertRules.groups;
  };

  prometheusConfig = {
    global = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
      external_labels = {monitor = "prometheus";};
    };

    alerting.alertmanagers = lib.optional (cfg.alertmanagerTargets != []) {
      static_configs = [{targets = cfg.alertmanagerTargets;}];
    };

    rule_files = ["${cfg.dataDir}/rules/*.yml"];
    scrape_configs = scrapeConfigs.all;
  };
}
