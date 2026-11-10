# HighIOWait

**What it means.** The CPU has spent over 30% of its time waiting for I/O and at least one disk is busy more than 80% of the time, for 10 minutes. Storage is the bottleneck.

**Likely causes.** A heavy read/write job; a ZFS scrub or resilver (common on `nixnas1`); a failing disk returning slow responses; swapping.

**First three commands.**
1. `iostat -x 5 3` (look for the busy device and high `await`)
2. `sudo iotop -oPa`
3. `zpool status` (is a scrub or resilver running?) and `sudo smartctl -a /dev/<device> | grep -i -E 'error|status'`

**Fix.** Wait for or pause the heavy job (`zpool scrub -p tanks` to pause a scrub), spread the load, or replace a slow or failing disk.

**Escalate when.** One disk is much slower than its peers or SMART/ZFS errors appear.

**Related alerts.** HighCPULoad, SwapUsage, ZpoolDeviceErrors, SMARTErrorLogGrowing.
