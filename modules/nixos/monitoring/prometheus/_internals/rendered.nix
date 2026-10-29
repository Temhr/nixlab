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
  bb = cfg.maintenance.exporters.blackbox;
  alertFeatures =
    cfg.maintenance.alerts.features
    // {
      backup = cfg.maintenance.exporters.backup.enable;
      dns = bb.enable && bb.dnsTargets != [];
      alertmanagerWired = cfg.alertmanagerTargets != [];
      blackboxProbes = bb.enable && (bb.httpTargets != [] || bb.icmpTargets != [] || bb.sslTargets != [] || bb.tcpTargets != [] || bb.httpInsecureTargets != []);
    };
  alertGroups = import ./maintenance-alerts.nix {
    features = alertFeatures;
    expectedMounts = cfg.maintenance.expectedMounts;
  };
in {
  rules = {
    groups =
      alertRulesConfig.groups
      ++ alertGroups.core
      ++ lib.optionals cfg.maintenance.enable alertGroups.maintenance;
  };

  prometheusConfig = {
    global = {
      scrape_interval = cfg.scrapeInterval;
      evaluation_interval = cfg.evaluationInterval;
      external_labels = {
        monitor = "prometheus";
        host = config.networking.hostName;
      };
    };

    alerting.alertmanagers = lib.optional (cfg.alertmanagerTargets != []) {
      static_configs = [{targets = cfg.alertmanagerTargets;}];
    };

    rule_files = ["${cfg.dataDir}/rules/*.yml"];
    scrape_configs = scrapeConfigs.all;
  };
}
