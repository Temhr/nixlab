# PrometheusCompactionFailing

**What it means.** Prometheus's TSDB compactions have failed in the last 3 hours. Old data is not being compacted or cleaned up, and the data directory can keep growing.

**Likely causes.** `/data` is out of space or inodes; wrong ownership after a rebuild; a corrupt block; disk I/O errors.

**First three commands.**
1. `journalctl -u prometheus --since -6h --no-pager | grep -i compact`
2. `df -h /data; df -i /data`
3. `ls -la /data/prometheus/data`

**Fix.** Free space (see CriticalDiskSpace), and check `systemctl status prometheus-permissions` for ownership problems. If one block is corrupt, find it with `promtool tsdb list /data/prometheus/data`, stop Prometheus, move that block directory aside and start it again.

**Escalate when.** Failures continue after space and permissions are fine, or the kernel reports I/O errors for the disk.

**Related alerts.** PrometheusWALCorruption, CriticalDiskSpace, PrometheusNoRecentSamples.
