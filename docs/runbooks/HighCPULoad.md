# HighCPULoad

**What it means.** The 5-minute load average is above 1.5 per CPU core and has been for 30 minutes: more work is waiting than the CPU can run.

**Likely causes.** A runaway or busy process; heavy builds or scrubs; processes blocked on slow I/O (load counts them too); too little CPU for the workload.

**First three commands.**
1. `uptime` and `top -bn1 | head -20`
2. `cat /proc/pressure/cpu` and `cat /proc/pressure/io`
3. `ps -eo pid,stat,pcpu,comm --sort=-pcpu | head`

**Fix.** Identify the heavy process and stop, limit (`CPUQuota=`/`Nice=` in its unit) or reschedule it. If the load is I/O-bound (many processes in `D` state), look at HighIOWait instead.

**Escalate when.** The system is unresponsive, or the load is high with an idle CPU (I/O or lock problem).

**Related alerts.** HighIOWait, HighMemoryUsage, CPUThrottling.
