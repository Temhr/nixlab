{
  groups = [
    # ═══════════════════════════════════════════════════════
    # I. Hardware & Physical Layer
    # ═══════════════════════════════════════════════════════
    {
      name = "hardware_health";
      interval = "30s";
      rules = [
        # 1. CPU Temperature
        {
          alert = "HighCPUTemperature";
          expr = "node_hwmon_temp_celsius{chip=~'coretemp|k10temp|amdgpu|nvidia|nvme'} > 80";
          for = "5m";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "CPU temperature high on {{ $labels.instance }}";
            description = "CPU temp is {{ $value }}°C (threshold: 80°C)";
          };
        }
        {
          alert = "CriticalCPUTemperature";
          expr = "node_hwmon_temp_celsius{chip=~'coretemp|k10temp|amdgpu|nvidia|nvme'} > 90";
          for = "2m";
          labels = {
            severity = "critical";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "CRITICAL: CPU temperature on {{ $labels.instance }}";
            description = "CPU temp is {{ $value }}°C - immediate attention required";
          };
        }
        # 1. CPU Throttling
        {
          alert = "CPUThrottling";
          expr = ''
            (
              node_cpu_scaling_frequency_hertz
                < (node_cpu_scaling_frequency_max_hertz * 0.60)
            )
            and
            (
              rate(node_cpu_seconds_total{mode!="idle"}[5m]) > 0.5
            )
          '';
          for = "10m";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "CPU throttling detected on {{ $labels.instance }}";
            description = "CPU frequency reduced (running <60% of max) while under significant load. Check cooling or power settings.";
          };
        }
        # 1. Fan Speed (if available)
        {
          alert = "FanSpeedLow";
          expr = "node_hwmon_fan_rpm < 1000";
          for = "5m";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "Fan speed low on {{ $labels.instance }}";
            description = "Fan {{ $labels.sensor }} running at {{ $value }} RPM";
          };
        }
        # 2. Disk Space
        {
          alert = "LowDiskSpace";
          expr = "(node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 20";
          for = "5m";
          labels = {
            severity = "warning";
            category = "storage";
            checklist_section = "I.2";
          };
          annotations = {
            summary = "Low disk space on {{ $labels.instance }}";
            description = "{{ $labels.mountpoint }} has {{ $value | humanizePercentage }} free";
          };
        }
        {
          alert = "CriticalDiskSpace";
          expr = "(node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10";
          for = "2m";
          labels = {
            severity = "critical";
            category = "storage";
            checklist_section = "I.2";
          };
          annotations = {
            summary = "CRITICAL: Disk almost full on {{ $labels.instance }}";
            description = "{{ $labels.mountpoint }} only has {{ $value | humanizePercentage }} free";
          };
        }
        # 2. Inode Usage
        {
          alert = "HighInodeUsage";
          expr = "(node_filesystem_files_free / node_filesystem_files) * 100 < 20";
          for = "5m";
          labels = {
            severity = "warning";
            category = "storage";
            checklist_section = "I.2";
          };
          annotations = {
            summary = "High inode usage on {{ $labels.instance }}";
            description = "{{ $labels.mountpoint }} has {{ $value | humanizePercentage }} inodes free";
          };
        }
        # 3. Network Interface Errors
        {
          alert = "NetworkInterfaceErrors";
          expr = "rate(node_network_receive_errs_total[5m]) > 10 or rate(node_network_transmit_errs_total[5m]) > 10";
          for = "5m";
          labels = {
            severity = "warning";
            category = "network";
            checklist_section = "I.3";
          };
          annotations = {
            summary = "Network errors on {{ $labels.instance }}";
            description = "Interface {{ $labels.device }} showing packet errors";
          };
        }
        # 3. Network Drops
        {
          alert = "NetworkPacketDrops";
          expr = "rate(node_network_receive_drop_total[5m]) > 50 or rate(node_network_transmit_drop_total[5m]) > 50";
          for = "5m";
          labels = {
            severity = "warning";
            category = "network";
            checklist_section = "I.3";
          };
          annotations = {
            summary = "Packet drops on {{ $labels.instance }}";
            description = "Interface {{ $labels.device }} dropping packets";
          };
        }
      ];
    }

    # ═══════════════════════════════════════════════════════
    # II. Operating System & Kernel
    # ═══════════════════════════════════════════════════════
    {
      name = "os_health";
      interval = "1m";
      rules = [
        # 5. System Logs - OOM Kills
        {
          alert = "OutOfMemoryKills";
          expr = "increase(node_vmstat_oom_kill[1h]) > 0";
          labels = {
            severity = "critical";
            category = "os";
            checklist_section = "II.5";
          };
          annotations = {
            summary = "OOM kills detected on {{ $labels.instance }}";
            description = "{{ $value }} processes killed due to out-of-memory";
          };
        }
        # 6. CPU Load
        {
          alert = "HighCPULoad";
          expr = ''node_load5 / count(node_cpu_seconds_total{mode="idle"}) without (cpu, mode) > 0.7'';
          for = "10m";
          labels = {
            severity = "warning";
            category = "os";
            checklist_section = "II.6";
          };
          annotations = {
            summary = "High CPU load on {{ $labels.instance }}";
            description = "5-min load average is {{ $value | humanize }} (>70% of cores)";
          };
        }
        # 6. Memory Usage
        {
          alert = "HighMemoryUsage";
          expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85";
          for = "5m";
          labels = {
            severity = "warning";
            category = "os";
            checklist_section = "II.6";
          };
          annotations = {
            summary = "High memory usage on {{ $labels.instance }}";
            description = "Memory usage at {{ $value | humanizePercentage }}";
          };
        }
        # 6. Swap Usage
        {
          alert = "SwapUsage";
          expr = "(1 - (node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes)) * 100 > 50";
          for = "5m";
          labels = {
            severity = "warning";
            category = "os";
            checklist_section = "II.6";
          };
          annotations = {
            summary = "Swap usage detected on {{ $labels.instance }}";
            description = "Swap usage at {{ $value | humanizePercentage }} - possible memory pressure";
          };
        }
        # 6. High I/O Wait
        {
          alert = "HighIOWait";
          expr = ''rate(node_cpu_seconds_total{mode="iowait"}[5m]) * 100 > 30'';
          for = "10m";
          labels = {
            severity = "warning";
            category = "os";
            checklist_section = "II.6";
          };
          annotations = {
            summary = "High I/O wait on {{ $labels.instance }}";
            description = "CPU spending {{ $value | humanizePercentage }} time waiting for I/O";
          };
        }
      ];
    }

    # ═══════════════════════════════════════════════════════
    # III. Storage Integrity & Backups
    # ═══════════════════════════════════════════════════════
    {
      name = "storage_backups";
      interval = "5m";
      rules = [
        # 7. Backup Job Failures (requires custom exporter)
        {
          alert = "BackupJobFailed";
          expr = "backup_job_last_success_timestamp < (time() - 86400)";
          for = "1h";
          labels = {
            severity = "critical";
            category = "backup";
            checklist_section = "III.7";
          };
          annotations = {
            summary = "Backup job {{ $labels.job_name }} failed";
            description = "No successful backup in 24+ hours";
          };
        }
        # 7. Backup Size Anomaly
        {
          alert = "BackupSizeAnomaly";
          expr = "abs(backup_job_size_bytes - backup_job_size_bytes offset 7d) / backup_job_size_bytes offset 7d > 0.3";
          for = "1h";
          labels = {
            severity = "warning";
            category = "backup";
            checklist_section = "III.7";
          };
          annotations = {
            summary = "Backup size changed significantly for {{ $labels.job_name }}";
            description = "Backup size differs >30% from last week";
          };
        }
      ];
    }

    # ═══════════════════════════════════════════════════════
    # IV. Networking & Security
    # ═══════════════════════════════════════════════════════
    {
      name = "network_security";
      interval = "1m";
      rules = [
        # 12. DNS Resolution Failures
        {
          alert = "DNSResolutionFailure";
          expr = ''probe_success{job="blackbox-dns"} == 0'';
          for = "3m";
          labels = {
            severity = "critical";
            category = "network";
            checklist_section = "IV.12";
          };
          annotations = {
            summary = "DNS resolution failing for {{ $labels.target }}";
            description = "Cannot resolve DNS queries";
          };
        }
        # 12. High Network Latency
        {
          alert = "HighNetworkLatency";
          expr = ''probe_duration_seconds{job="blackbox-icmp"} > 0.1'';
          for = "5m";
          labels = {
            severity = "warning";
            category = "network";
            checklist_section = "IV.12";
          };
          annotations = {
            summary = "High latency to {{ $labels.target }}";
            description = "Latency is {{ $value | humanizeDuration }}";
          };
        }
        # 13. Certificate Expiring Soon
        {
          alert = "CertificateExpiringSoon";
          expr = "(probe_ssl_earliest_cert_expiry - time()) / 86400 < 30";
          for = "1h";
          labels = {
            severity = "warning";
            category = "security";
            checklist_section = "IV.13";
          };
          annotations = {
            summary = "Certificate expiring soon for {{ $labels.instance }}";
            description = "Certificate expires in {{ $value | humanizeDuration }}";
          };
        }
        {
          alert = "CertificateExpiringCritical";
          expr = "(probe_ssl_earliest_cert_expiry - time()) / 86400 < 7";
          for = "1h";
          labels = {
            severity = "critical";
            category = "security";
            checklist_section = "IV.13";
          };
          annotations = {
            summary = "CRITICAL: Certificate expiring for {{ $labels.instance }}";
            description = "Certificate expires in {{ $value | humanizeDuration }}";
          };
        }
      ];
    }

    # ═══════════════════════════════════════════════════════
    # V. Application & Service Health
    # ═══════════════════════════════════════════════════════
    {
      name = "service_health";
      interval = "30s";
      rules = [
        # 14. Service Down
        {
          alert = "ServiceDown";
          expr = ''up{job!~"prometheus|node"} == 0'';
          for = "2m";
          labels = {
            severity = "critical";
            category = "service";
            checklist_section = "V.14";
          };
          annotations = {
            summary = "Service {{ $labels.job }} is down";
            description = "Service on {{ $labels.instance }} not responding";
          };
        }
        # 14. Systemd Service Failed
        {
          alert = "SystemdServiceFailed";
          expr = ''node_systemd_unit_state{state="failed"} == 1'';
          for = "5m";
          labels = {
            severity = "warning";
            category = "service";
            checklist_section = "V.14";
          };
          annotations = {
            summary = "Systemd service failed on {{ $labels.instance }}";
            description = "Service {{ $labels.name }} is in failed state";
          };
        }
        # 15. Database Replication Lag (PostgreSQL example)
        {
          alert = "PostgresReplicationLag";
          expr = "pg_replication_lag_seconds > 300";
          for = "5m";
          labels = {
            severity = "warning";
            category = "database";
            checklist_section = "V.15";
          };
          annotations = {
            summary = "PostgreSQL replication lag on {{ $labels.instance }}";
            description = "Replication lag is {{ $value | humanizeDuration }}";
          };
        }
        # 16. High HTTP Error Rate
        {
          alert = "HighHTTPErrorRate";
          expr = ''rate(traefik_service_requests_total{code=~"5.."}[5m]) > 10'';
          for = "5m";
          labels = {
            severity = "warning";
            category = "web";
            checklist_section = "V.16";
          };
          annotations = {
            summary = "High HTTP 5xx error rate for {{ $labels.service }}";
            description = "{{ $value }} errors/sec on {{ $labels.service }}";
          };
        }
      ];
    }

    # ═══════════════════════════════════════════════════════
    # VI. Virtualization & Containers
    # ═══════════════════════════════════════════════════════
    {
      name = "container_health";
      interval = "30s";
      rules = [
        # 18. Container Restart Loop
        {
          alert = "ContainerRestartLoop";
          expr = ''rate(container_last_seen{name!=""}[5m]) > 0.01'';
          for = "10m";
          labels = {
            severity = "warning";
            category = "container";
            checklist_section = "VI.18";
          };
          annotations = {
            summary = "Container {{ $labels.name }} restarting frequently";
            description = "Container on {{ $labels.instance }} in restart loop";
          };
        }
        # 18. High Container Memory Usage
        {
          alert = "ContainerHighMemory";
          expr = "(container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100 > 90";
          for = "5m";
          labels = {
            severity = "warning";
            category = "container";
            checklist_section = "VI.18";
          };
          annotations = {
            summary = "Container {{ $labels.name }} high memory usage";
            description = "Memory usage at {{ $value | humanizePercentage }}";
          };
        }
      ];
    }

    # ═══════════════════════════════════════════════════════
    # Recording Rules for Dashboard
    # ═══════════════════════════════════════════════════════
    {
      name = "maintenance_metrics";
      interval = "1m";
      rules = [
        # Overall system health score (0-100)
        {
          record = "system:health_score:percentage";
          expr = ''
            100 - (
              count(ALERTS{alertstate="firing", severity="critical"}) * 20 +
              count(ALERTS{alertstate="firing", severity="warning"}) * 5
            )
          '';
        }
        # Active alerts by category
        {
          record = "system:alerts_by_category:count";
          expr = ''count by (category) (ALERTS{alertstate="firing"})'';
        }
        # Active alerts by checklist section
        {
          record = "system:alerts_by_section:count";
          expr = ''count by (checklist_section) (ALERTS{alertstate="firing"})'';
        }
        # Disk space summary
        {
          record = "node:disk_usage:percentage";
          expr = "(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100";
        }
        # Memory usage summary
        {
          record = "node:memory_usage:percentage";
          expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
        }
        # CPU usage summary (non-idle)
        {
          record = "node:cpu_usage:percentage";
          expr = ''(1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100'';
        }
      ];
    }
  ];
}
