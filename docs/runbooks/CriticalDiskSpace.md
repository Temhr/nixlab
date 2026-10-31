# CriticalDiskSpace
**What it means.** A filesystem has under 10% free.
**First three commands.**
1. `df -h` and `df -i`
2. `du -xh --max-depth=2 <mountpoint> | sort -h | tail -15`
3. `nix-store --gc --print-dead | tail -1; sudo nix-collect-garbage -d` (only on /)
**Fix.** Clear logs, old generations or snapshots; grow the volume. On /data check Loki and Prometheus retention.
**Escalate when.** It fills faster than you can free it (DiskWillFillIn24h was already firing).
