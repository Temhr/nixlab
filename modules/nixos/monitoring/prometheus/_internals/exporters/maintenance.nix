# ============================================================================
# FILE: prometheus/exporters/maintenance.nix
# ============================================================================
{
  config,
  lib,
  pkgs,
}: let
  cfg = config.services.prometheus-nixlab;

  blackboxConfig = pkgs.writeText "blackbox.yml" ''
    modules:
      http_2xx:
        prober: http
        timeout: 5s
        http:
          valid_status_codes: []
          method: GET
          preferred_ip_protocol: "ip4"

      dns_a:
        prober: dns
        timeout: 5s
        dns:
          query_name: "${cfg.maintenance.exporters.blackbox.dnsQueryName}"
          query_type: "A"
          preferred_ip_protocol: "ip4"

      icmp:
        prober: icmp
        timeout: 5s
        icmp:
          preferred_ip_protocol: "ip4"

      tcp_connect:
        prober: tcp
        timeout: 5s
  '';

  mkBackupExporterScript = pkgs.writeShellScript "backup-exporter" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    METRICS_DIR="/var/lib/node_exporter"
    METRICS_FILE="$METRICS_DIR/backup_metrics.prom"
    mkdir -p "$METRICS_DIR"

    while true; do
      {
        if [[ -f "${cfg.maintenance.exporters.backup.timestampFile}" ]]; then
          LAST_BACKUP=$(cat "${cfg.maintenance.exporters.backup.timestampFile}")
          if [[ "$LAST_BACKUP" =~ ^[0-9]+$ ]]; then
            echo "backup_job_last_success_timestamp{job_name=\"${cfg.maintenance.exporters.backup.jobName}\"} $LAST_BACKUP"
          fi
        fi

        if [[ -f "${cfg.maintenance.exporters.backup.sizeFile}" ]]; then
          BACKUP_SIZE=$(cat "${cfg.maintenance.exporters.backup.sizeFile}")
          if [[ "$BACKUP_SIZE" =~ ^[0-9]+$ ]]; then
            echo "backup_job_size_bytes{job_name=\"${cfg.maintenance.exporters.backup.jobName}\"} $BACKUP_SIZE"
          fi
        fi
      } > "$METRICS_FILE.tmp"

      mv "$METRICS_FILE.tmp" "$METRICS_FILE"
      sleep 300
    done
  '';
in {
  # Exporter configurations for services.prometheus.exporters
  exporters = {
    systemd = lib.mkIf (cfg.maintenance.enable && cfg.maintenance.exporters.systemd) {
      enable = true;
      port = cfg.systemdExporterPort;
      listenAddress = lib.mkDefault "127.0.0.1";
    };

    blackbox = lib.mkIf (cfg.maintenance.enable && cfg.maintenance.exporters.blackbox.enable) {
      enable = true;
      port = cfg.blackboxPort;
      listenAddress = lib.mkDefault "127.0.0.1";
      configFile = blackboxConfig;
    };

    smartctl = lib.mkIf (cfg.maintenance.enable && cfg.maintenance.exporters.smartctl.enable) {
      enable = true;
      port = cfg.smartctlPort;
      listenAddress = lib.mkDefault "127.0.0.1";
      devices = cfg.maintenance.exporters.smartctl.devices;
    };
  };

  # Additional systemd services
  services = {
    prometheus-smartctl-exporter =
      lib.mkIf
      (cfg.maintenance.enable && cfg.maintenance.exporters.smartctl.enable) {
        serviceConfig = {
          AmbientCapabilities = ["CAP_SYS_RAWIO"];
          CapabilityBoundingSet = ["CAP_SYS_RAWIO"];
          DeviceAllow = ["/dev/sd* r" "/dev/nvme* r"];
          PrivateDevices = lib.mkForce false;
        };
      };

    backup-status-exporter =
      lib.mkIf
      (cfg.maintenance.enable && cfg.maintenance.exporters.backup.enable) {
        description = "Backup Status Exporter";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "prometheus";
          Group = "prometheus";
          Restart = "always";
          RestartSec = "10s";
          ExecStart = mkBackupExporterScript;
        };
      };
  };
}
