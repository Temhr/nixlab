# OutOfMemoryKills

**What it means.** The kernel's OOM killer terminated at least one process in the last hour because the host ran out of memory.

**Likely causes.** A leaking or oversized process; too many services for the RAM installed; a service without a memory limit; on a ZFS host, the ARC claiming too much memory.

**First three commands.**
1. `sudo journalctl -k --since -2h | grep -i -E 'out of memory|oom-kill|Killed process'`
2. `free -h` and `ps aux --sort=-%mem | head -15`
3. `cat /proc/pressure/memory`

**Fix.** Identify what was killed and what was using the memory. Limit the offender (`MemoryMax=` in its systemd unit), reduce what runs on the host, or add RAM or swap. On `nixnas1`, consider capping the ZFS ARC with `zfs_arc_max` if the ARC is crowding out services.

**Escalate when.** It recurs, or the killed process is something critical (the observability stack, NFS, ZFS).

**Related alerts.** HighMemoryUsage, SwapUsage, JournalOOMKill (log-based alert).
