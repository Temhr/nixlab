# ============================================================================
# FILE: prometheus/exporters/node.nix
# ============================================================================
# Prometheus Node Exporter Service Configuration
#
# The node exporter collects hardware and OS metrics from the host system,
# including CPU usage, memory, disk I/O, network statistics, and more.
# These metrics are exposed in Prometheus format on an HTTP endpoint.
# ============================================================================

{ config, lib, pkgs }:
let
  cfg = config.services.prometheus-custom;

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
    "--collector.processes"       # Process counts and states
    "--collector.systemd"         # Systemd unit states and metrics
    # Hardware monitoring
    "--collector.hwmon"           # Hardware sensors (temp, voltage, fans)
    # Network details
    "--collector.netclass"        # Network interface properties
    "--collector.netdev"          # Network device statistics (default but explicit)
    # Disk usage prediction
    "--collector.filesystem.mount-points-exclude=^/(dev|proc|run|sys)($|/)"
  ] ++ lib.optionals cfg.maintenance.enable [
    # Custom metrics from text files (when maintenance mode enabled)
    "--collector.textfile.directory=/var/lib/node_exporter"
  ]);

in
{
  # Human-readable service description shown in systemctl status
  description = "Prometheus Node Exporter";
  # Start this service automatically on system boot as part of multi-user target
  wantedBy = [ "multi-user.target" ];
  # Wait for network to be available before starting
  after = [ "network.target" ];
  serviceConfig = {
    # Simple service type - systemd considers it started once ExecStart process begins
    Type = "simple";
    # Run as unprivileged prometheus user for security
    User = "prometheus";
    Group = "prometheus";
    # Command to start the node exporter with all collector flags
    ExecStart = "${pkgs.prometheus-node-exporter}/bin/node_exporter "
      + "--web.listen-address=localhost:9100 "
      + collectorFlags;
    # Automatically restart on failure
    Restart = "on-failure";
    RestartSec = "10s";
    # Automatically create and manage directories
    StateDirectory = "node_exporter";
    StateDirectoryMode = "0750";

    # ========================================================================
    # Security Hardening Options
    # ========================================================================
    # Prevent privilege escalation
    NoNewPrivileges = true;
    # Filesystem protections
    PrivateTmp = true;              # Use private /tmp directory
    ProtectSystem = "strict";       # Make system directories read-only
    ProtectHome = true;             # Hide /home directories

    # Resource limits
    MemoryMax = "256M";             # Limit memory usage
    TasksMax = "10";                # Limit number of processes
  };
}
