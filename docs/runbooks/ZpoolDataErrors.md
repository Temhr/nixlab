# ZpoolDataErrors

**What it means.** ZFS reports permanent data errors in the pool: files or blocks it could not repair, typically because redundancy was missing or the same data was bad on several disks.

**Likely causes.** Corruption that happened while the pool was already degraded (RAIDZ1 had no parity left to repair from); multiple disks with errors; a failed disk plus bad sectors on another; RAM or controller faults.

**First three commands.**
1. `zpool status -v tanks` (lists the affected files under "errors")
2. `sudo smartctl -a /dev/disk/by-id/<device>` for each disk
3. `zpool events -v | tail -80`

**Fix.** Restore the listed files from backup, or delete them if they can be regenerated (`/mirror` may also have a copy on the mirror peer, nixnas2). Make sure the pool is healthy again (`ZpoolNotOnline` resolved, resilver finished), then run `sudo zpool scrub tanks`. The error list is cleared after a clean scrub (sometimes it takes two); `sudo zpool clear tanks` after that.

**Notes.** An error against a file name that no longer exists means the file was already deleted; the entry disappears after a scrub.

**Escalate when.** Always treat this as serious. Back up everything readable now, find the root cause (failed disk, controller, RAM) before it recurs, and do not just clear the counters.

**Related alerts.** ZpoolDeviceErrors, ZpoolScrubErrors, ZpoolNotOnline, SMARTStatusFailed, KernelFilesystemError.
