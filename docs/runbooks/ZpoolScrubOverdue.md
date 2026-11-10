# ZpoolScrubOverdue

**What it means.** No scrub of the pool has finished in over 10 days. The weekly `services.zfs.autoScrub` should complete one every 7 days; a scrub is what finds silent corruption before you need the data.

**Likely causes.** The scrub timer or service is not running or keeps failing; the host was off or rebooted at scrub time; scrubs keep getting cancelled (a resilver or manual `zpool scrub -s` stops one); the pool was newly set up and no scrub has finished yet.

**First three commands.**
1. `systemctl list-timers | grep -i scrub` and `systemctl list-units 'zfs-scrub*'`
2. `journalctl -u 'zfs-scrub*' --since -14d --no-pager | tail -50`
3. `zpool status tanks | grep -A3 scan` and `cat /var/lib/zfs-integrity-metrics/last-scrub`

**Fix.** Start one now: `sudo zpool scrub tanks` (about 2 hours at this pool's speed). If the timer is missing or failing, check `services.zfs.autoScrub` in `zfs-raidz1-pool.nix` and the journal from step 2.

**Notes.** The timestamp comes from `/var/lib/zfs-integrity-metrics/last-scrub`, written by `zfs-integrity-metrics` when a scrub finishes. A resilver replaces the scan information in `zpool status`, but not this file. If that file is missing, the clock starts when the exporter first runs. A scrub still in progress does not count until it finishes.

**Escalate when.** Scrubs start but never finish, or finish with errors (ZpoolScrubErrors).

**Related alerts.** ZpoolScrubErrors, ZpoolNotOnline, SystemdServiceFailed.
