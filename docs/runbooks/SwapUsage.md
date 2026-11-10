# SwapUsage

**What it means.** More than 50% of swap has been in use for 5 minutes, a possible sign of memory pressure.

**Likely causes.** A memory-hungry process; too little RAM for the workload; idle pages pushed to swap long ago (not harmful by itself).

**First three commands.**
1. `free -h` and `swapon --show`
2. `ps aux --sort=-%mem | head -15`
3. `vmstat 1 5` (sustained non-zero `si`/`so` means active swapping) and `cat /proc/pressure/memory`

**Fix.** If memory pressure is real, find and limit the offender (`MemoryMax=` in its unit) or add RAM. If it is only idle pages, it can be left alone; `sudo swapoff -a && sudo swapon -a` clears it when there is enough free RAM.

**Escalate when.** There is heavy active swapping (slow system) or OOM kills follow.

**Related alerts.** HighMemoryUsage, OutOfMemoryKills, HighIOWait.
