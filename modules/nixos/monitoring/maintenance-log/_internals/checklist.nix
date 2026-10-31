# The maintenance checklist: single source of truth for section codes, names, hints and cadences.
# `cadence` is the maximum age in seconds of the last completed entry before MaintenanceOverdue fires
# (null means "tracked but never overdue").
[
  {
    code = "I.1";
    name = "Hardware Health";
    hint = "CPU temp check, fan inspection, RAM test";
    cadence = null;
  }
  {
    code = "I.2";
    name = "Storage Capacity";
    hint = "Check disk space, verify inode usage";
    cadence = null;
  }
  {
    code = "I.3";
    name = "Network Hardware";
    hint = "Cables, switch ports, link speeds";
    cadence = null;
  }
  {
    code = "II.4";
    name = "OS Updates";
    hint = "Review the nixos-upgrade log, reboot if pending";
    cadence = null;
  }
  {
    code = "II.5";
    name = "System Logs";
    hint = "Review journal errors, kernel messages";
    cadence = null;
  }
  {
    code = "II.6";
    name = "Resource Utilization";
    hint = "CPU, memory and swap trends";
    cadence = null;
  }
  {
    code = "III.7";
    name = "Backup Status";
    hint = "Verify backup success, check offsite sync, restore test";
    cadence = null;
  }
  {
    code = "III.8";
    name = "Filesystem Health";
    hint = "Run ZFS scrub, Btrfs balance, filesystem check";
    cadence = null;
  }
  {
    code = "III.9";
    name = "Snapshot Management";
    hint = "Retention, space used by snapshots";
    cadence = null;
  }
  {
    code = "IV.10";
    name = "Firewall & Access Control";
    hint = "Review open ports and firewall rules";
    cadence = null;
  }
  {
    code = "IV.11";
    name = "Authentication & Identity";
    hint = "Users, SSH keys, sudoers";
    cadence = null;
  }
  {
    code = "IV.12";
    name = "Network Connectivity";
    hint = "Gateway, DNS, peer reachability";
    cadence = null;
  }
  {
    code = "IV.13";
    name = "Certificate Management";
    hint = "Check cert expiry, verify ACME renewals";
    cadence = null;
  }
  {
    code = "V.14";
    name = "Service Availability";
    hint = "systemctl --failed, restart loops";
    cadence = null;
  }
  {
    code = "V.15";
    name = "Database Maintenance";
    hint = "Vacuum, replication, backups";
    cadence = null;
  }
  {
    code = "V.16";
    name = "Web Services";
    hint = "Reverse proxy routes, error rates";
    cadence = null;
  }
  {
    code = "V.17";
    name = "Message Queues";
    hint = "Queue depths, dead letters";
    cadence = null;
  }
  {
    code = "VI.18";
    name = "Container Infrastructure";
    hint = "Image pruning, restart loops, resource limits";
    cadence = null;
  }
  {
    code = "VI.19";
    name = "VM Maintenance";
    hint = "Guest agents, disk usage, old snapshots";
    cadence = null;
  }
  {
    code = "VI.20";
    name = "Orchestration";
    hint = "Cluster health, pending upgrades";
    cadence = null;
  }
  {
    code = "VII.21";
    name = "Metrics Coverage";
    hint = "Scrape targets all up, new services scraped";
    cadence = null;
  }
  {
    code = "VII.22";
    name = "Alerting";
    hint = "Send a test alert, review silences";
    cadence = null;
  }
  {
    code = "VII.23";
    name = "Log Management";
    hint = "Retention, disk used by logs";
    cadence = null;
  }
  {
    code = "VIII.24";
    name = "Configuration Drift";
    hint = "nixos-rebuild dry-build, git status of the repo";
    cadence = null;
  }
  {
    code = "VIII.25";
    name = "Documentation";
    hint = "Update runbooks and the network map";
    cadence = null;
  }
  {
    code = "VIII.26";
    name = "Compliance & Policy";
    hint = "License and policy review";
    cadence = null;
  }
  {
    code = "IX.27";
    name = "Redundancy Systems";
    hint = "UPS, mirror peers, failover test";
    cadence = null;
  }
  {
    code = "IX.28";
    name = "Disaster Recovery";
    hint = "DR rehearsal, restore a backup to a scratch host";
    cadence = null;
  }
  {
    code = "X.29";
    name = "Weekly Tasks";
    hint = "Review alerts, backups, certificates, logs";
    cadence = null; # 8 * 86400;
  }
  {
    code = "X.30";
    name = "Monthly Tasks";
    hint = "OS updates, ZFS scrub, backup restore test";
    cadence = null; # 35 * 86400;
  }
  {
    code = "X.31";
    name = "Quarterly Tasks";
    hint = "Hardware cleaning, DR rehearsal, access audit";
    cadence = null; # 100 * 86400;
  }
]
