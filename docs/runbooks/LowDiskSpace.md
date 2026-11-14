# LowDiskSpace

**What it means.** A filesystem has between 10% and 20% free space for 5 minutes. Below 10% the critical alert (CriticalDiskSpace) takes over. ZFS datasets are excluded; they use ZpoolLowFree.

**Likely causes.** Normal data growth; old Nix generations; logs; Loki or Prometheus data on `/data`; large downloads.

**First three commands.**
1. `df -h` and `df -i`
2. `du -xh --max-depth=2 <mountpoint> | sort -h | tail -15`
3. `nix-store --gc --print-dead | tail -1` (only on `/`)

**Fix.** Clear what you can: `sudo nix-collect-garbage -d` on `/`, old logs, caches. On `/data`, review Loki and Prometheus retention (`services.nixlab-observability.{loki,prometheus}.retention` and `retentionSize`).

**Escalate when.** It is dropping fast (see DiskWillFillIn24h) or reaches CriticalDiskSpace.

**Related alerts.** CriticalDiskSpace, DiskWillFillIn24h, HighInodeUsage.
