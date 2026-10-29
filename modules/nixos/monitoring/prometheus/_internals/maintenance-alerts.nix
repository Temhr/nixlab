{
  features ? {},
  # Tests set this to false so expected labels do not have to contain the long `condition` label.
  conditionLabel ? true,
  expectedMounts ? [],
}: let
  # ── Helpers ────────────────────────────────────────────────────────────────
  # Collapse whitespace so multi-line exprs become a single readable line.
  squash = s:
    builtins.concatStringsSep " "
    (builtins.filter (x: builtins.isString x && x != "")
      (builtins.split "[[:space:]]+" s));

  # Adds a `condition` label to every alert rule containing its own PromQL expr
  # and `for` duration. Labels end up on the ALERTS series, so Grafana can show
  # *why* an alert fired straight from the ALERTS metric (no Prometheus web UI
  # trip needed). Because it is generated from the rule itself, it can never
  # drift out of sync with the expression.
  withCondition = rule:
    if rule ? alert
    then
      rule
      // {
        labels =
          rule.labels
          // {
            condition =
              squash rule.expr
              + (
                if rule ? for
                then " (for ${rule.for})"
                else ""
              );
          };
      }
    else rule;

  # Rules may carry `requires = "<feature>";`. They load only when that
  # feature flag is true. The attribute is stripped before output.
  isEnabled = r: !(r ? requires) || (features.${r.requires} or false);
  stripGate = r: removeAttrs r ["requires"];
  prune = gs:
    builtins.filter (g: g.rules != []) (map (g:
      (removeAttrs g ["core"])
      // {
        rules = map (r:
          stripGate (
            if conditionLabel
            then withCondition r
            else r
          )) (builtins.filter isEnabled g.rules);
      })
    gs);

  # Filesystems that should never alert (virtual / duplicate mounts).
  # /nix/store is a bind mount of the root fs on NixOS and would double-alert.
  fsFilter = ''fstype!~"tmpfs|overlay|squashfs|ramfs|devtmpfs|nsfs|erofs|fusectl|fuse.gvfsd-fuse|fuse.portal|zfs",mountpoint!~"/nix/store|/run/.*"'';

  # Virtual network interfaces that routinely show drops/errors.
  netFilter = ''device!~"lo|veth.*|docker.*|br-.*|virbr.*"'';
in rec {
  allGroups = [
    # ═══════════════════════════════════════════════════════
    # I. Hardware & Physical Layer
    # ═══════════════════════════════════════════════════════
    {
      name = "hardware_health";
      interval = "30s";
      rules = [
        # 1. Temperature
        # NOTE: the `chip` label is a PCI/platform path (e.g. platform_coretemp_0),
        # the friendly name lives in node_hwmon_chip_names{chip_name=...}, so we join.
        {
          alert = "HighCPUTemperature";
          expr = ''
            (
              node_hwmon_temp_celsius
              * on (instance, chip) group_left (chip_name)
              node_hwmon_chip_names{chip_name=~"coretemp|k10temp|amdgpu"}
            ) > 80 <= 90
          '';
          for = "5m";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "High temperature on {{ $labels.instance }} ({{ $labels.chip_name }}/{{ $labels.sensor }})";
            description = ''{{ $labels.chip_name }} sensor {{ $labels.sensor }} is {{ $value | printf "%.0f" }}°C (warning above 80°C, critical above 90°C)'';
          };
        }
        {
          alert = "CriticalCPUTemperature";
          expr = ''
            (
              node_hwmon_temp_celsius
              * on (instance, chip) group_left (chip_name)
              node_hwmon_chip_names{chip_name=~"coretemp|k10temp|amdgpu"}
            ) > 90
          '';
          for = "2m";
          labels = {
            severity = "critical";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "CRITICAL: temperature on {{ $labels.instance }} ({{ $labels.chip_name }}/{{ $labels.sensor }})";
            description = ''{{ $labels.chip_name }} sensor {{ $labels.sensor }} is {{ $value | printf "%.0f" }}°C - immediate attention required'';
          };
        }
        {
          alert = "NVMeHighTemperature";
          expr = ''
            (
              node_hwmon_temp_celsius
              * on (instance, chip) group_left (chip_name)
              node_hwmon_chip_names{chip_name="nvme"}
            ) > 75 <= 85
          '';
          for = "10m";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "High NVMe temperature on {{ $labels.instance }}";
            description = ''NVMe sensor {{ $labels.sensor }} is {{ $value | printf "%.0f" }}°C (warning above 75°C, critical above 85°C)'';
          };
        }
        {
          alert = "NVMeCriticalTemperature";
          expr = ''
            (
              node_hwmon_temp_celsius
              * on (instance, chip) group_left (chip_name)
              node_hwmon_chip_names{chip_name="nvme"}
            ) > 85
          '';
          for = "5m";
          labels = {
            severity = "critical";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "CRITICAL: NVMe temperature on {{ $labels.instance }}";
            description = ''NVMe sensor {{ $labels.sensor }} is {{ $value | printf "%.0f" }}°C - immediate attention required'';
          };
        }
        # 1. CPU Throttling
        # Fixed: the two sides of `and` need matching labels (instance, cpu);
        # previously the `mode` label on the right side meant it could never match.
        # Aggregated per host so a 16-core box doesn't raise 16 alerts.
        {
          alert = "CPUThrottling";
          expr = ''
            count by (instance) (
              (
                node_cpu_scaling_frequency_hertz
                  < (node_cpu_scaling_frequency_max_hertz * 0.60)
              )
              and on (instance, cpu)
              (
                sum by (instance, cpu) (rate(node_cpu_seconds_total{mode!~"idle|iowait|steal"}[5m])) > 0.5
              )
            ) > 0
            unless on (instance) (max by (instance) (node_power_supply_online{type="Mains"}) == 0)
          '';
          for = "10m";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "CPU throttling detected on {{ $labels.instance }}";
            description = "{{ $value }} core(s) running below 60% of max frequency while under load. Check cooling or power settings.";
          };
        }
        # 1. Fan Speed (if available)
        # Only alerts when the machine is warm, so fan-stop-at-idle laptops don't false-alarm.
        {
          alert = "FanSpeedLow";
          expr = ''
            (node_hwmon_fan_rpm < 1000 and max_over_time(node_hwmon_fan_rpm[7d]) > 1500)
            and on (instance)
            (max by (instance) (node_hwmon_temp_celsius) > 55)
          '';
          for = "5m";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "Fan speed low on {{ $labels.instance }}";
            description = ''Fan {{ $labels.sensor }} ({{ $labels.chip }}) at {{ $value | printf "%.0f" }} RPM while the system is above 55°C'';
          };
        }
        # 2. Disk Space (warning band is 10-20% so it doesn't double-fire with critical)
        {
          alert = "LowDiskSpace";
          expr = ''(node_filesystem_avail_bytes{${fsFilter}} / node_filesystem_size_bytes{${fsFilter}}) * 100 < 20 >= 10'';
          for = "5m";
          labels = {
            severity = "warning";
            category = "storage";
            checklist_section = "I.2";
          };
          annotations = {
            summary = "Low disk space on {{ $labels.instance }}";
            description = ''{{ $labels.mountpoint }} ({{ $labels.device }}) has {{ $value | printf "%.1f" }}% free (warning below 20%)'';
          };
        }
        {
          alert = "CriticalDiskSpace";
          expr = ''(node_filesystem_avail_bytes{${fsFilter}} / node_filesystem_size_bytes{${fsFilter}}) * 100 < 10'';
          for = "2m";
          labels = {
            severity = "critical";
            category = "storage";
            checklist_section = "I.2";
          };
          annotations = {
            summary = "CRITICAL: Disk almost full on {{ $labels.instance }}";
            description = ''{{ $labels.mountpoint }} ({{ $labels.device }}) only has {{ $value | printf "%.1f" }}% free'';
          };
        }
        # 2. Disk fill prediction (new)
        {
          alert = "DiskWillFillIn24h";
          expr = ''
            (predict_linear(node_filesystem_avail_bytes{${fsFilter}}[6h], 24 * 3600) < 0)
            and
            (node_filesystem_avail_bytes{${fsFilter}} / node_filesystem_size_bytes{${fsFilter}} * 100 < 50)
          '';
          for = "1h";
          labels = {
            severity = "warning";
            category = "storage";
            checklist_section = "I.2";
          };
          annotations = {
            summary = "Disk on {{ $labels.instance }} projected to fill within 24h";
            description = "{{ $labels.mountpoint }} is on track to run out of space within a day at the current rate of growth";
          };
        }
        # 2. Inode Usage
        {
          alert = "HighInodeUsage";
          expr = ''(node_filesystem_files_free{${fsFilter}} / node_filesystem_files{${fsFilter}}) * 100 < 20'';
          for = "5m";
          labels = {
            severity = "warning";
            category = "storage";
            checklist_section = "I.2";
          };
          annotations = {
            summary = "High inode usage on {{ $labels.instance }}";
            description = ''{{ $labels.mountpoint }} has {{ $value | printf "%.1f" }}% inodes free'';
          };
        }
        # 3. Network Interface Errors
        {
          alert = "NetworkInterfaceErrors";
          expr = ''rate(node_network_receive_errs_total{${netFilter}}[5m]) > 10 or rate(node_network_transmit_errs_total{${netFilter}}[5m]) > 10'';
          for = "5m";
          labels = {
            severity = "warning";
            category = "network";
            checklist_section = "I.3";
          };
          annotations = {
            summary = "Network errors on {{ $labels.instance }}";
            description = ''Interface {{ $labels.device }} showing {{ $value | printf "%.1f" }} packet errors/s'';
          };
        }
        # 3. Network Drops
        {
          alert = "NetworkPacketDrops";
          expr = ''rate(node_network_receive_drop_total{${netFilter}}[5m]) > 50 or rate(node_network_transmit_drop_total{${netFilter}}[5m]) > 50'';
          for = "5m";
          labels = {
            severity = "warning";
            category = "network";
            checklist_section = "I.3";
          };
          annotations = {
            summary = "Packet drops on {{ $labels.instance }}";
            description = ''Interface {{ $labels.device }} dropping {{ $value | printf "%.0f" }} packets/s'';
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
            description = ''{{ $value | printf "%.0f" }} process(es) killed due to out-of-memory in the last hour'';
          };
        }
        # 5. Clock drift (new)
        {
          alert = "ClockDrift";
          expr = "abs(node_timex_offset_seconds) > 0.1";
          for = "10m";
          labels = {
            severity = "warning";
            category = "os";
            checklist_section = "II.5";
          };
          annotations = {
            summary = "Clock drift on {{ $labels.instance }}";
            description = ''System clock is {{ $value | printf "%.2f" }}s off - check NTP/chrony/timesyncd'';
          };
        }
        # 5. Clock not synchronised (new)
        # ClockDrift only fires if timesyncd/chrony reports a large offset. This
        # catches the case where the kernel itself says the clock is unsynced.
        {
          alert = "ClockNotSynced";
          expr = "node_timex_sync_status == 0";
          for = "15m";
          labels = {
            severity = "warning";
            category = "os";
            checklist_section = "II.5";
          };
          annotations = {
            summary = "Clock not synchronised on {{ $labels.instance }}";
            description = "Kernel reports the system clock is not NTP-synchronised. A bad clock can poison the Prometheus TSDB with future-dated samples.";
          };
        }
        # 6. CPU Load
        {
          alert = "HighCPULoad";
          expr = ''node_load5 / count(node_cpu_seconds_total{mode="idle"}) without (cpu, mode) > 1.5'';
          for = "30m";
          labels = {
            severity = "warning";
            category = "os";
            checklist_section = "II.6";
          };
          annotations = {
            summary = "High CPU load on {{ $labels.instance }}";
            description = ''5-min load average is {{ $value | printf "%.2f" }} per core (threshold 1.5)'';
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
            description = ''Memory usage at {{ $value | printf "%.1f" }}% (threshold 85%)'';
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
            description = ''Swap usage at {{ $value | printf "%.1f" }}% (threshold 50%) - possible memory pressure'';
          };
        }
        # 6. High I/O Wait
        # Fixed: the old second clause compared a per-second rate against 50 (max possible is 1),
        # so the alert could never fire. Now average iowait across cores per host.
        {
          alert = "HighIOWait";
          expr = ''avg by (instance) (rate(node_cpu_seconds_total{mode="iowait"}[5m])) * 100 > 30'';
          for = "10m";
          labels = {
            severity = "warning";
            category = "os";
            checklist_section = "II.6";
          };
          annotations = {
            summary = "High I/O wait on {{ $labels.instance }}";
            description = ''CPU spending {{ $value | printf "%.1f" }}% of its time waiting for I/O (threshold 30%)'';
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
        # Rewritten as `time() - ts` so $value is the age and can be shown.
        {
          alert = "BackupJobFailed";
          requires = "backup";
          expr = "time() - backup_job_last_success_timestamp > 86400";
          for = "1h";
          labels = {
            severity = "critical";
            category = "backup";
            checklist_section = "III.7";
          };
          annotations = {
            summary = "Backup job {{ $labels.job_name }} failed";
            description = "Last successful backup was {{ $value | humanizeDuration }} ago (threshold 24h)";
          };
        }
        # 7. Backup Size Anomaly
        {
          alert = "BackupSizeAnomaly";
          requires = "backup";
          expr = "abs(backup_job_size_bytes - backup_job_size_bytes offset 7d) / backup_job_size_bytes offset 7d > 0.3";
          for = "1h";
          labels = {
            severity = "warning";
            category = "backup";
            checklist_section = "III.7";
          };
          annotations = {
            summary = "Backup size changed significantly for {{ $labels.job_name }}";
            description = "Backup size differs by {{ $value | humanizePercentage }} from last week (threshold 30%)";
          };
        }
        {
          alert = "BackupMetricsMissing";
          requires = "backup";
          expr = "absent(backup_job_last_success_timestamp)";
          for = "1h";
          labels = {
            severity = "warning";
            category = "backup";
            checklist_section = "III.7";
          };
          annotations = {
            summary = "Backup metrics are missing";
            description = "backup_job_last_success_timestamp is absent: the timestamp file is missing or invalid, or the exporter is not running. BackupJobFailed cannot fire without it.";
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
          requires = "dns";
          expr = ''probe_success{job="blackbox-dns"} == 0'';
          for = "3m";
          labels = {
            severity = "critical";
            category = "network";
            checklist_section = "IV.12";
          };
          annotations = {
            summary = "DNS resolution failing for {{ $labels.instance }}";
            description = "Blackbox DNS probe to {{ $labels.instance }} has been failing";
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
            summary = "High latency to {{ $labels.instance }}";
            description = "ICMP round trip is {{ $value | humanizeDuration }} (threshold 100ms)";
          };
        }
        # 13. Certificate Expiring Soon
        # Fixed: expr is in days but was formatted with humanizeDuration (expects seconds).
        # Also ignores probes with no TLS (expiry metric = 0) and bands the warning at 7-30 days.
        {
          alert = "CertificateExpiringSoon";
          expr = ''((probe_ssl_earliest_cert_expiry - time()) / 86400 < 30 >= 7) and probe_ssl_earliest_cert_expiry > 0'';
          for = "1h";
          labels = {
            severity = "warning";
            category = "security";
            checklist_section = "IV.13";
          };
          annotations = {
            summary = "Certificate expiring soon for {{ $labels.instance }}";
            description = ''Certificate expires in {{ $value | printf "%.1f" }} days'';
          };
        }
        {
          alert = "CertificateExpiringCritical";
          expr = ''((probe_ssl_earliest_cert_expiry - time()) / 86400 < 7) and probe_ssl_earliest_cert_expiry > 0'';
          for = "1h";
          labels = {
            severity = "critical";
            category = "security";
            checklist_section = "IV.13";
          };
          annotations = {
            summary = "CRITICAL: Certificate expiring for {{ $labels.instance }}";
            description = ''Certificate expires in {{ $value | printf "%.1f" }} days (negative = already expired)'';
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
        # 14. Host Down (new) - ServiceDown deliberately excludes job="node",
        # which meant a whole machine disappearing raised no alert at all.
        {
          alert = "HostDown";
          expr = ''up{job="node"} == 0'';
          for = "5m";
          labels = {
            severity = "warning";
            category = "service";
            checklist_section = "V.14";
          };
          annotations = {
            summary = "Host {{ $labels.instance }} is unreachable";
            description = "node_exporter on {{ $labels.instance }} has not responded for 5+ minutes (machine off, asleep or network down)";
          };
        }
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
            summary = "Service {{ $labels.job }} is down on {{ $labels.instance }}";
            description = "Scrape target {{ $labels.job }} at {{ $labels.instance }} is not responding";
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
            summary = "Systemd unit {{ $labels.name }} failed on {{ $labels.instance }}";
            description = "Unit {{ $labels.name }} has been in the failed state for 5+ minutes";
          };
        }
        # 15. Database Replication Lag (PostgreSQL example)
        {
          alert = "PostgresReplicationLag";
          requires = "postgres";
          expr = "pg_replication_lag_seconds > 300";
          for = "5m";
          labels = {
            severity = "warning";
            category = "database";
            checklist_section = "V.15";
          };
          annotations = {
            summary = "PostgreSQL replication lag on {{ $labels.instance }}";
            description = "Replication lag is {{ $value | humanizeDuration }} (threshold 5m)";
          };
        }
        # 16. High HTTP Error Rate
        # Changed to a ratio: 10 errors/sec is unreachable on a homelab.
        # Requires >0.05 req/s so idle services don't flap on a single 5xx.
        {
          alert = "HighHTTPErrorRate";
          requires = "traefik";
          expr = ''
            (
              sum by (service) (rate(traefik_service_requests_total{code=~"5.."}[5m]))
              / sum by (service) (rate(traefik_service_requests_total[5m]))
              > 0.05
            )
            and
            (sum by (service) (rate(traefik_service_requests_total[5m])) > 0.05)
          '';
          for = "5m";
          labels = {
            severity = "warning";
            category = "web";
            checklist_section = "V.16";
          };
          annotations = {
            summary = "High HTTP 5xx error rate for {{ $labels.service }}";
            description = ''{{ $value | humanizePercentage }} of requests to {{ $labels.service }} are returning 5xx (threshold 5%)'';
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
        # Fixed: container_last_seen is a timestamp gauge, so rate() of it is ~1 for every
        # running container (the old rule fired for all of them). Count start-time changes instead.
        {
          alert = "ContainerRestartLoop";
          requires = "containers";
          expr = ''changes(container_start_time_seconds{name!=""}[15m]) > 2'';
          for = "5m";
          labels = {
            severity = "warning";
            category = "container";
            checklist_section = "VI.18";
          };
          annotations = {
            summary = "Container {{ $labels.name }} restarting frequently";
            description = ''Container {{ $labels.name }} on {{ $labels.instance }} restarted {{ $value | printf "%.0f" }} times in 15m'';
          };
        }
        # 18. High Container Memory Usage
        # Fixed: containers with no limit report limit=0 (division -> +Inf -> always firing).
        {
          alert = "ContainerHighMemory";
          requires = "containers";
          expr = ''(container_memory_working_set_bytes{name!=""} / (container_spec_memory_limit_bytes{name!=""} > 0)) * 100 > 90'';
          for = "5m";
          labels = {
            severity = "warning";
            category = "container";
            checklist_section = "VI.18";
          };
          annotations = {
            summary = "Container {{ $labels.name }} high memory usage";
            description = ''{{ $labels.name }} on {{ $labels.instance }} is using {{ $value | printf "%.1f" }}% of its memory limit (threshold 90%)'';
          };
        }
      ];
    }

    # ═══════════════════════════════════════════════════════
    # IV/V. Blackbox probes (HTTP, ICMP, TCP, TLS)
    # ═══════════════════════════════════════════════════════
    {
      name = "probes";
      interval = "1m";
      rules = [
        {
          alert = "ProbeFailed";
          requires = "blackboxProbes";
          expr = ''probe_success{job=~"blackbox-http|blackbox-icmp"} == 0'';
          for = "5m";
          labels = {
            severity = "warning";
            category = "network";
            checklist_section = "IV.12";
          };
          annotations = {
            summary = "Probe failing: {{ $labels.instance }}";
            description = "{{ $labels.job }} probe to {{ $labels.instance }} has failed for 5+ minutes";
          };
        }
        {
          alert = "SSLProbeFailed";
          requires = "blackboxProbes";
          expr = ''probe_success{job="blackbox-ssl"} == 0'';
          for = "10m";
          labels = {
            severity = "warning";
            category = "security";
            checklist_section = "IV.13";
          };
          annotations = {
            summary = "TLS probe failing: {{ $labels.instance }}";
            description = "Handshake or HTTP check failed; certificate expiry alerts cannot evaluate.";
          };
        }
      ];
    }

    # ═══════════════════════════════════════════════════════
    # VII. Monitoring Stack Self-Health
    #
    # Prometheus stores its own metrics (and the ALERTS series) in the same TSDB
    # that can go bad, so "metric X is high" rules are unreliable for this
    # failure class: the samples that would trigger them are the ones being
    # rejected. The absent_over_time rule is the dependable one, because it
    # fires on *missing* data. Make sure Alertmanager (-> ntfy) is wired up:
    # notifications still go out even when ALERTS can't be stored for Grafana.
    # ═══════════════════════════════════════════════════════
    {
      name = "monitoring_stack";
      core = true;
      interval = "1m";
      rules = [
        # 19. Prometheus has stopped recording its own samples: every scrape rejected as out-of-bounds, so
        # `up` was empty everywhere while /-/healthy still returned OK.
        {
          alert = "PrometheusNoRecentSamples";
          expr = ''absent_over_time(up{job="prometheus"}[10m])'';
          for = "5m";
          labels = {
            severity = "critical";
            category = "monitoring";
            checklist_section = "VII.21";
          };
          annotations = {
            summary = "Prometheus has no recent samples for itself";
            description = "No up{job=\"prometheus\"} sample in 10m. Check `journalctl -u prometheus | grep -i 'out of bounds'` and /api/v1/status/tsdb (headStats.minTime vs now).";
          };
        }
        # 19. Samples rejected for bad timestamps (best-effort: only fires while
        # some of this metric's own samples are still being accepted).
        {
          alert = "PrometheusSamplesOutOfBounds";
          expr = "increase(prometheus_target_scrapes_sample_out_of_bounds_total[10m]) > 0";
          for = "10m";
          labels = {
            severity = "critical";
            category = "monitoring";
            checklist_section = "VII.21";
          };
          annotations = {
            summary = "Prometheus is rejecting samples as out of bounds";
            description = ''{{ $value | printf "%.0f" }} samples rejected in 10m - usually a clock jump. Compare the host clock with the TSDB head time range.'';
          };
        }
        # 19. TSDB head newer than wall clock (clock was ahead, then corrected).
        {
          alert = "PrometheusHeadInFuture";
          expr = "prometheus_tsdb_head_max_time_seconds - time() > 3600";
          for = "5m";
          labels = {
            severity = "critical";
            category = "monitoring";
            checklist_section = "VII.21";
          };
          annotations = {
            summary = "Prometheus TSDB head is in the future";
            description = ''Head max time is {{ $value | humanizeDuration }} ahead of now. New samples will be rejected until the WAL/head is cleared.'';
          };
        }
        # 19. Rule evaluation errors: a rule that errors silently never fires.
        {
          alert = "PrometheusRuleEvaluationFailures";
          expr = "increase(prometheus_rule_evaluation_failures_total[15m]) > 0";
          for = "5m";
          labels = {
            severity = "warning";
            category = "monitoring";
            checklist_section = "VII.22";
          };
          annotations = {
            summary = "Prometheus rule evaluation is failing";
            description = "Some alert or recording rules are erroring and silently not firing.";
          };
        }
      ];
    }

    # ═══════════════════════════════════════════════════════
    # VII. Self-health of Prometheus, Alertmanager, Loki and Alloy
    # ═══════════════════════════════════════════════════════
    {
      name = "stack_self_health";
      core = true;
      interval = "1m";
      rules = [
        {
          alert = "PrometheusConfigReloadFailed";
          expr = "prometheus_config_last_reload_successful == 0";
          for = "5m";
          labels = {
            severity = "critical";
            category = "monitoring";
            checklist_section = "VII.21";
          };
          annotations = {
            summary = "Prometheus failed to reload its configuration";
            description = "The running configuration is stale. Run promtool check config and read the journal for the reason.";
          };
        }
        {
          alert = "PrometheusNoAlertmanager";
          requires = "alertmanagerWired";
          expr = "prometheus_notifications_alertmanagers_discovered < 1";
          for = "10m";
          labels = {
            severity = "critical";
            category = "monitoring";
            checklist_section = "VII.22";
          };
          annotations = {
            summary = "Prometheus has no Alertmanager";
            description = "Alerts are evaluated but cannot be delivered.";
          };
        }
        {
          alert = "PrometheusNotificationsFailing";
          expr = "rate(prometheus_notifications_errors_total[5m]) > 0";
          for = "10m";
          labels = {
            severity = "critical";
            category = "monitoring";
            checklist_section = "VII.22";
          };
          annotations = {
            summary = "Prometheus cannot reach Alertmanager";
            description = "Errors sending alerts to {{ $labels.alertmanager }}.";
          };
        }
        {
          alert = "AlertmanagerNotifyFailing";
          expr = "rate(alertmanager_notifications_failed_total[10m]) > 0";
          for = "10m";
          labels = {
            severity = "critical";
            category = "monitoring";
            checklist_section = "VII.22";
          };
          annotations = {
            summary = "Alertmanager notifications are failing";
            description = "Integration {{ $labels.integration }} is failing; alerts are not reaching you.";
          };
        }
        {
          alert = "PrometheusWALCorruption";
          expr = "increase(prometheus_tsdb_wal_corruptions_total[1h]) > 0";
          labels = {
            severity = "warning";
            category = "monitoring";
            checklist_section = "VII.21";
          };
          annotations = {
            summary = "Prometheus WAL corruption";
            description = "The TSDB reported WAL corruptions in the last hour.";
          };
        }
        {
          alert = "PrometheusCompactionFailing";
          expr = "increase(prometheus_tsdb_compactions_failed_total[3h]) > 0";
          labels = {
            severity = "warning";
            category = "monitoring";
            checklist_section = "VII.21";
          };
          annotations = {
            summary = "Prometheus TSDB compactions are failing";
            description = "Check disk space and the Prometheus journal.";
          };
        }
        {
          alert = "LokiDiscardingSamples";
          expr = "sum by (reason) (rate(loki_discarded_samples_total[10m])) > 0";
          for = "10m";
          labels = {
            severity = "warning";
            category = "monitoring";
            checklist_section = "VII.23";
          };
          annotations = {
            summary = "Loki is discarding log lines";
            description = "Reason: {{ $labels.reason }}. A rate limit or stream limit is dropping logs.";
          };
        }
        {
          alert = "AlloyDroppingEntries";
          expr = "rate(loki_write_dropped_entries_total[5m]) > 0";
          for = "10m";
          labels = {
            severity = "warning";
            category = "monitoring";
            checklist_section = "VII.23";
          };
          annotations = {
            summary = "Alloy is dropping log entries";
            description = "Alloy cannot deliver entries to Loki.";
          };
        }
      ];
    }

    # ═══════════════════════════════════════════════════════
    # I. Drive health from the smartctl exporter (ATA, NVMe, SAS/SCSI)
    # ═══════════════════════════════════════════════════════
    {
      name = "smart_health";
      interval = "5m";
      rules = [
        {
          alert = "SMARTStatusFailed";
          expr = "smartctl_device_smart_status == 0";
          for = "5m";
          labels = {
            severity = "critical";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "SMART self-assessment FAILED on {{ $labels.instance }} ({{ $labels.device }})";
            description = "The drive reports a failing SMART status. Back up and replace it.";
          };
        }
        {
          alert = "SMARTErrorLogGrowing";
          expr = "delta(smartctl_device_error_log_count[7d]) > 0";
          for = "1h";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "SMART error log is growing on {{ $labels.instance }} ({{ $labels.device }})";
            description = "New entries appeared in the drive's error log during the last 7 days.";
          };
        }
        {
          alert = "SMARTSectorsGrowing";
          expr = ''delta(smartctl_device_attribute{attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable",attribute_value_type="raw"}[7d]) > 0'';
          for = "1h";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "Bad sectors increasing on {{ $labels.instance }} ({{ $labels.device }})";
            description = "{{ $labels.attribute_name }} grew in the last 7 days: the drive is wearing out.";
          };
        }
        {
          alert = "NVMeWearHigh";
          expr = "smartctl_device_percentage_used > 80";
          for = "1h";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "NVMe wear above 80% on {{ $labels.instance }} ({{ $labels.device }})";
            description = ''{{ $value | printf "%.0f" }}% of the rated endurance is used. Plan a replacement.'';
          };
        }
        {
          alert = "NVMeCriticalWarning";
          expr = "smartctl_device_critical_warning > 0";
          labels = {
            severity = "critical";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "NVMe critical warning on {{ $labels.instance }} ({{ $labels.device }})";
            description = "The controller raised a critical-warning flag (spare, temperature, reliability or read-only).";
          };
        }
        {
          alert = "NVMeMediaErrors";
          expr = "delta(smartctl_device_media_errors[7d]) > 0";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "NVMe media errors on {{ $labels.instance }} ({{ $labels.device }})";
            description = "Unrecovered data integrity errors increased in the last 7 days.";
          };
        }
        {
          alert = "NVMeSpareLow";
          expr = "smartctl_device_available_spare < smartctl_device_available_spare_threshold";
          for = "1h";
          labels = {
            severity = "critical";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "NVMe spare capacity below threshold on {{ $labels.instance }} ({{ $labels.device }})";
            description = "The drive has used up its reserve of spare blocks.";
          };
        }
        {
          alert = "SCSIDefectsGrowing";
          expr = "delta(smartctl_scsi_grown_defect_list[7d]) > 0";
          for = "1h";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "Grown defects increasing on {{ $labels.instance }} ({{ $labels.device }})";
            description = "A SAS/SCSI drive added entries to its grown defect list.";
          };
        }
        {
          alert = "SCSIUncorrectedErrors";
          expr = ''delta({__name__=~"smartctl_(read|write)_total_uncorrected_errors"}[7d]) > 0'';
          for = "1h";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "Uncorrected I/O errors on {{ $labels.instance }} ({{ $labels.device }})";
            description = "Uncorrected read or write errors increased in the last 7 days.";
          };
        }
      ];
    }

    # ═══════════════════════════════════════════════════════
    # III. Filesystem integrity
    # ═══════════════════════════════════════════════════════
    {
      name = "filesystem_integrity";
      interval = "1m";
      rules =
        [
          {
            alert = "FilesystemReadOnly";
            expr = ''node_filesystem_readonly{${fsFilter}} == 1'';
            for = "2m";
            labels = {
              severity = "critical";
              category = "storage";
              checklist_section = "I.2";
            };
            annotations = {
              summary = "Filesystem went read-only on {{ $labels.instance }}";
              description = "{{ $labels.mountpoint }} ({{ $labels.device }}) is mounted read-only, usually after I/O errors. Check dmesg.";
            };
          }
          {
            alert = "FilesystemDeviceError";
            expr = ''node_filesystem_device_error{${fsFilter}} == 1'';
            for = "5m";
            labels = {
              severity = "warning";
              category = "storage";
              checklist_section = "I.2";
            };
            annotations = {
              summary = "Cannot read filesystem state on {{ $labels.instance }}";
              description = "{{ $labels.mountpoint }} ({{ $labels.device }}) failed to report size (stale NFS mount or bad device).";
            };
          }
        ]
        ++ map (m: {
          alert = "ExpectedMountMissing";
          expr = ''absent(node_filesystem_size_bytes{mountpoint="${m}"})'';
          for = "5m";
          labels = {
            severity = "critical";
            category = "storage";
            checklist_section = "I.2";
          };
          annotations = {
            summary = "Expected mount ${m} is missing";
            description = "node_filesystem_size_bytes has no series for ${m}: the mount is absent, unmounted or the host is not reporting.";
          };
        })
        expectedMounts;
    }

    # ═══════════════════════════════════════════════════════
    # III. ZFS pools
    # ═══════════════════════════════════════════════════════
    {
      name = "zfs_health";
      interval = "1m";
      rules = [
        {
          alert = "ZpoolNotOnline";
          expr = ''node_zfs_zpool_state{state!="online"} == 1'';
          for = "2m";
          labels = {
            severity = "critical";
            category = "storage";
            checklist_section = "III.8";
          };
          annotations = {
            summary = "ZFS pool {{ $labels.zpool }} is {{ $labels.state }} on {{ $labels.instance }}";
            description = "Run zpool status -x. A degraded pool has lost redundancy.";
          };
        }
        {
          alert = "ZpoolLowFree";
          expr = ''
            min by (instance, pool) (
              100 * label_replace(
                node_filesystem_avail_bytes{fstype="zfs"} / node_filesystem_size_bytes{fstype="zfs"},
                "pool", "$1", "device", "([^/@]+).*"
              )
            ) < 15
          '';
          for = "15m";
          labels = {
            severity = "warning";
            category = "storage";
            checklist_section = "III.8";
          };
          annotations = {
            summary = "ZFS pool {{ $labels.pool }} is nearly full on {{ $labels.instance }}";
            description = ''Only {{ $value | printf "%.1f" }}% free (warning below 15%).'';
          };
        }
      ];
    }

    # ═══════════════════════════════════════════════════════
    # I. Laptop battery health
    # ═══════════════════════════════════════════════════════
    {
      name = "battery_health";
      interval = "5m";
      rules = [
        {
          alert = "BatteryHealthDegraded";
          expr = ''
            (
              (node_power_supply_energy_full{power_supply=~"BAT.*"} / node_power_supply_energy_full_design{power_supply=~"BAT.*"})
              or
              (node_power_supply_charge_full{power_supply=~"BAT.*"} / node_power_supply_charge_full_design{power_supply=~"BAT.*"})
            ) * 100 < 60
          '';
          for = "1h";
          labels = {
            severity = "warning";
            category = "hardware";
            checklist_section = "I.1";
          };
          annotations = {
            summary = "Battery wear on {{ $labels.instance }}";
            description = ''{{ $labels.power_supply }} holds {{ $value | printf "%.0f" }}% of its design capacity'';
          };
        }
      ];
    }

    # ═══════════════════════════════════════════════════════
    # Recording Rules for Dashboard
    # (not passed through withCondition: only alerts get that label)
    # ═══════════════════════════════════════════════════════
    {
      name = "maintenance_metrics";
      core = true;
      interval = "1m";
      rules = [
        # Overall system health score (0-100), clamped so it can't go negative
        {
          record = "system:health_score:percentage";
          expr = ''
            clamp_min(
              100 - (
                (count(ALERTS{alertstate="firing", severity="critical"}) or vector(0)) * 20 +
                (count(ALERTS{alertstate="firing", severity="warning"}) or vector(0)) * 5
              ),
              0
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
          expr = ''(1 - (node_filesystem_avail_bytes{${fsFilter}} / node_filesystem_size_bytes{${fsFilter}})) * 100'';
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

  # Everything (used by the unit-test harness and the all-features check).
  groups = prune allGroups;
  # Always loaded, even when maintenance.enable = false.
  core = prune (builtins.filter (g: g.core or false) allGroups);
  # Loaded only when maintenance.enable = true.
  maintenance = prune (builtins.filter (g: !(g.core or false)) allGroups);
}
