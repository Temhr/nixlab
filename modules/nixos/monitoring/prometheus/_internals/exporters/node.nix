# ============================================================================
# FILE: prometheus/exporters/node.nix
# ============================================================================
# Prometheus Node Exporter Service Configuration
#
# The node exporter collects hardware and OS metrics from the host system,
# including CPU usage, memory, disk I/O, network statistics, and more.
# These metrics are exposed in Prometheus format on an HTTP endpoint.
# ============================================================================
{
  config,
  lib,
  pkgs,
  nixlabLib,
  ...
}: let
  cfg = config.services.prometheus-nixlab;

  # Build collector flags dynamically
  collectorFlags = lib.concatStringsSep " " ([
      # === ALWAYS ENABLED (DEFAULT) COLLECTORS ===
      # These run automatically: cpu, diskstats, filesystem, loadavg, meminfo,
      # netdev, netstat, stat, time, uname, vmstat

      # === EXPLICITLY ENABLED COLLECTORS ===
      # Enable Linux Pressure Stall Information (PSI) metrics
      # Shows CPU, memory, and I/O pressure - requires Linux 4.20+
      "--collector.pressure"
      # System statistics from /proc
      "--collector.processes" # Process counts and states
      "--collector.systemd" # Systemd unit states and metrics
      # Hardware monitoring
      "--collector.hwmon" # Hardware sensors (temp, voltage, fans)
      # Network details
      "--collector.netclass" # Network interface properties
      "--collector.netdev" # Network device statistics (default but explicit)
      # Disk usage prediction
      "--collector.filesystem.mount-points-exclude=^/(dev|proc|run|sys)($|/)"
    ]
    ++ lib.optionals cfg.maintenance.enable [
      # Custom metrics from text files (when maintenance mode enabled)
      "--collector.textfile.directory=/var/lib/node_exporter"
    ]);
in {
  description = "Prometheus Node Exporter";
  wantedBy = ["multi-user.target"];
  after = ["network.target"];
  serviceConfig =
    nixlabLib.mkServiceHardening {
      writablePaths = [];
    }
    // {
      Type = "simple";
      User = "prometheus";
      Group = "prometheus";
      ExecStart = "${pkgs.prometheus-node-exporter}/bin/node_exporter " + "--web.listen-address=localhost:9100 " + collectorFlags;
      Restart = "on-failure";
      RestartSec = "10s";
      StateDirectory = "node_exporter";
      StateDirectoryMode = "0750";
      MemoryMax = "256M";
      TasksMax = "10";
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_NETLINK" "AF_UNIX"];
      # node_exporter's hwmon/pressure/systemd collectors hit syscalls outside
      # @system-service intermittently (Go's randomized map iteration means
      # which collector probes first — and hits the restriction — varies
      # per boot). The original config had no syscall filter at all and was
      # stable; keep it off here rather than guess at exact syscall groups.
      SystemCallFilter = "";
    };
}
