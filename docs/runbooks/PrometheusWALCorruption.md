# PrometheusWALCorruption

**What it means.** Prometheus's TSDB reported write-ahead-log corruption in the last hour. Prometheus usually recovers by repairing or dropping the damaged segment.

**Likely causes.** An unclean shutdown (power loss, kill -9, crash); a full disk; disk or filesystem errors.

**First three commands.**
1. `journalctl -u prometheus --since -2h --no-pager | grep -i -E 'wal|corrupt'`
2. `ls -d /data/prometheus/data/*broken*` and `systemctl status prometheus-wal-recover`
3. `sudo dmesg -T | grep -i -E 'error|ext4|xfs|I/O' | tail -20`

**Fix.** Nothing is needed if Prometheus is running and ingesting; `mkWalSelfHeal` quarantines a bad WAL as `wal.broken-<timestamp>` and keeps the last two. Find out why it happened (power, disk, disk space). Delete old `*.broken-*` directories once you are sure you do not need them.

**Escalate when.** It recurs, or the kernel shows disk errors (check SMART and the filesystem).

**Related alerts.** PrometheusCompactionFailing, PrometheusNoRecentSamples, SMARTStatusFailed, FilesystemReadOnly.
