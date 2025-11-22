# ============================================================================
# FILE: prometheus/services/prometheus.nix
# ============================================================================
{ config, lib, pkgs }:

let
  cfg = config.services.prometheus-custom;
  scrapeConfigs = import ../scrape-configs.nix { inherit config lib; };

  # Alert rules
  alertRulesConfig = import ../alerts.nix;
  maintenanceAlertRules = if cfg.maintenance.enable
    then import ../maintenance-alerts.nix
    else { groups = []; };

  combinedAlertRules = {
    groups = alertRulesConfig.groups ++ maintenanceAlertRules.groups;
  };

  alertRulesJsonFile = builtins.toFile "alerts.json"
    (builtins.toJSON combinedAlertRules);

  # Prometheus configuration
  prometheusConfig = {
    global = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
      external_labels = { monitor = "prometheus"; };
    };

    alerting = {
      alertmanagers = [{
        static_configs = [{ targets = []; }];
      }];
    };

    rule_files = [ "${cfg.dataDir}/rules/*.yml" ];
    scrape_configs = scrapeConfigs.all;
  };

  prometheusJsonFile = builtins.toFile "prometheus.json"
    (builtins.toJSON prometheusConfig);

  # Config installer helper
  mkConfigInstaller = { jsonFile, yamlPath, mode ? "660" }: ''
    ${pkgs.remarshal}/bin/remarshal \
      -i ${jsonFile} \
      -o ${yamlPath}.tmp \
      -if json \
      -of yaml
    install -m ${mode} -o prometheus -g prometheus ${yamlPath}.tmp ${yamlPath}
  '';

  preStartScript = ''
    # Install main Prometheus config
    ${mkConfigInstaller {
      jsonFile = prometheusJsonFile;
      yamlPath = "${cfg.dataDir}/prometheus.yml";
    }}

    # Create and install alert rules
    mkdir -p ${cfg.dataDir}/rules
    ${mkConfigInstaller {
      jsonFile = alertRulesJsonFile;
      yamlPath = "${cfg.dataDir}/rules/alerts.yml";
      mode = "644";
    }}

    # Ensure data directory exists
    mkdir -p ${cfg.dataDir}/data
    chown prometheus:prometheus ${cfg.dataDir}/data
  '';
in
{
  description = "Prometheus Monitoring System";
  wantedBy = [ "multi-user.target" ];
  after = [ "network.target" ];

  serviceConfig = {
    Type = "simple";
    User = "prometheus";
    Group = "prometheus";
    ExecStart = ''
      ${cfg.package}/bin/prometheus \
        --config.file=${cfg.dataDir}/prometheus.yml \
        --storage.tsdb.path=${cfg.dataDir}/data \
        --storage.tsdb.retention.time=${cfg.retention} \
        --web.listen-address=${cfg.bindIP}:${toString cfg.port} \
        --web.console.templates=${cfg.package}/etc/prometheus/consoles \
        --web.console.libraries=${cfg.package}/etc/prometheus/console_libraries
    '';
    ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
    Restart = "on-failure";
    RestartSec = "10s";

    # Security hardening
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ReadWritePaths = [ cfg.dataDir ];
  };

  preStart = preStartScript;
}
