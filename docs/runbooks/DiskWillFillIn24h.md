# DiskWillFillIn24h

**What it means.** At the growth rate of the last 6 hours, a filesystem under 50% free will run out of space within 24 hours. This is an early warning, before LowDiskSpace.

**Likely causes.** A runaway log; a stuck process writing files; a large transfer or backup in progress; a crash dump or core file.

**First three commands.**
1. `df -h <mountpoint>`
2. `sudo du -xh --max-depth=2 <mountpoint> | sort -h | tail -15`
3. `sudo lsof +L1 | head` (deleted files still held open) and `ls -lt <suspect dir> | head`

**Fix.** Find what is growing and stop or throttle it, then free the space it used. If growth is expected (a big copy), make sure there is enough room for it to finish.

**Escalate when.** It is on `/`, `/data` or `/nix`, where a full disk affects the whole system and the observability stack itself.

**Related alerts.** LowDiskSpace, CriticalDiskSpace, HighInodeUsage.
