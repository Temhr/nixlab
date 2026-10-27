# ============================================================================
# FILE: prometheus/services/prometheus.nix
# ============================================================================
{
  config,
  lib,
  pkgs,
  nixlabLib,
}: let
  cfg = config.services.prometheus-nixlab;
  rendered = import ../rendered.nix {inherit config lib;};

  alertRulesJsonFile =
    builtins.toFile "alerts.json"
    (builtins.toJSON rendered.rules);

  prometheusJsonFile =
    builtins.toFile "prometheus.json"
    (builtins.toJSON rendered.prometheusConfig);

  # Config installer helper
  mkConfigInstaller = {
    jsonFile,
    yamlPath,
    mode ? "660",
  }: ''
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
in {
  description = "Prometheus Monitoring System";
  wantedBy = ["multi-user.target"];
  after = ["network.target" "prometheus-permissions.service" "time-sync.target"];
  wants = ["time-sync.target"];

  serviceConfig =
    nixlabLib.mkServiceHardening {
      writablePaths = [cfg.dataDir];
    }
    // {
      Type = "simple";
      User = "prometheus";
      Group = "prometheus";
      ExecStart = ''
        ${cfg.package}/bin/prometheus \
          --config.file=${cfg.dataDir}/prometheus.yml \
          --storage.tsdb.path=${cfg.dataDir}/data \
          --storage.tsdb.retention.time=${cfg.retention} \
          --web.listen-address=${cfg.listenAddress}:${toString cfg.port}
      '';
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      Restart = "on-failure";
      RestartSec = "10s";
    };

  preStart = preStartScript;
}
