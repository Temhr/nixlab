# BackupJobFailed

**What it means.** The last successful run of a backup job (the `job_name` label) was more than 24 hours ago, and has been for an hour.

**Likely causes.** The backup job failed or did not run (timer, network, credentials, target full or offline); the success timestamp file is not being updated.

**First three commands.**
1. `cat /var/lib/node_exporter/backup_metrics.prom`
2. `systemctl list-timers | grep -i backup` and `systemctl status <backup unit>`
3. `journalctl -u <backup unit> -n 80 --no-pager`

**Fix.** Fix the cause in the journal (credentials, destination, space), run the job manually, and confirm the timestamp file is refreshed so the metric updates (the exporter reads it every 5 minutes).

**Escalate when.** Several days have been missed. Verify you can actually restore from the last good backup.

**Related alerts.** BackupMetricsMissing, BackupSizeAnomaly, SystemdServiceFailed.
