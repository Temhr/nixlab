# BackupMetricsMissing

**What it means.** The `backup_job_last_success_timestamp` metric has been absent for an hour, so BackupJobFailed cannot fire.

**Likely causes.** The backup-status exporter is not running; its timestamp file is missing or does not contain a number; `/var/lib/node_exporter` is unwritable.

**First three commands.**
1. `systemctl status backup-status-exporter` and `journalctl -u backup-status-exporter -n 30 --no-pager`
2. `ls -l /var/lib/node_exporter/backup_metrics.prom`
3. `cat <timestampFile> <sizeFile>` (the paths set in `services.prometheus-nixlab.maintenance.exporters.backup`)

**Fix.** Make the backup job write a valid Unix timestamp to the timestamp file on success, and make sure the exporter unit is running.

**Escalate when.** You are unsure whether backups are running at all; check the backup job directly.

**Related alerts.** BackupJobFailed, BackupSizeAnomaly.
