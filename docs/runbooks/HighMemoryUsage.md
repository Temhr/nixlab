# HighMemoryUsage

**What it means.** More than 85% of memory has been in use (not counting reclaimable cache) for 5 minutes.

**Likely causes.** A memory-hungry or leaking process; too many services for the installed RAM; on a ZFS host, the ARC using a lot of memory (it is reclaimed under pressure, but is not counted as "available").

**First three commands.**
1. `free -h`
2. `ps aux --sort=-%mem | head -15`
3. `cat /proc/pressure/memory`

**Fix.** Find and limit the offender (`MemoryMax=` in its unit), or add RAM. On `nixnas1`, check the ARC size with `grep -E '^(size|c_max)' /proc/spl/kstat/zfs/arcstats` and cap it with `zfs_arc_max` if needed.

**Escalate when.** Swap is filling or OOM kills begin.

**Related alerts.** SwapUsage, OutOfMemoryKills, HighCPULoad.
