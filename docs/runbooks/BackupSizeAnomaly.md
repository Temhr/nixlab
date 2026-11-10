# BackupSizeAnomaly

**What it means.** A backup job's size differs by more than 30% from its size a week ago, for an hour.

**Likely causes.** A real change in the data (a large deletion or import); a path accidentally excluded or newly included; a partial or failed backup that still wrote a timestamp.

**First three commands.**
1. `cat /var/lib/node_exporter/backup_metrics.prom`
2. `journalctl -u <backup unit> --since -7d --no-pager | tail -60`
3. Compare the backup contents with the source (for example `du -sh` of both)

**Fix.** If the change is expected, no action is needed; the alert clears a week after the size stabilizes. If not, find what was excluded or truncated and run a fresh full backup.

**Escalate when.** The backup is far smaller than expected, which can mean missing data.

**Related alerts.** BackupJobFailed, BackupMetricsMissing.
