# ZpoolScrubErrors

**What it means.** The last scrub that finished reported errors it could not repair. The alert stays until a later scrub finishes cleanly.

**Likely causes.** Corruption on disk that parity could not fix (often because the pool was degraded), a failing disk, or a faulty controller or RAM.

**First three commands.**
1. `zpool status -v tanks`
2. `zpool status -j --json-int tanks | jq .pools.tanks.scan_stats`
3. `sudo smartctl -a /dev/disk/by-id/<device>` for each disk

**Fix.** Restore the files listed by `zpool status -v` from backup, fix the underlying cause (replace a failing disk, see ZpoolDeviceErrors), then run `sudo zpool scrub tanks` again. If it finishes clean, the alert resolves by itself; clear leftover counters with `sudo zpool clear tanks`.

**Notes.** The scrub result comes from `/var/lib/zfs-integrity-metrics/last-scrub`, which only updates when a scrub finishes, so the alert will not clear until another scrub completes.

**Escalate when.** The same files or disks show errors on consecutive scrubs, or ZpoolDataErrors is also firing.

**Related alerts.** ZpoolDataErrors, ZpoolDeviceErrors, ZpoolScrubOverdue, ZpoolNotOnline.
