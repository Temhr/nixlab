# ZpoolDeviceErrors

**What it means.** A vdev (a disk, the raidz group, or the pool root) has non-zero READ, WRITE or CHECKSUM error counters in `zpool status`. The pool can still show ONLINE. The `type` and `device` labels say which counter and which vdev.

**Likely causes.**
- READ or WRITE errors: failing disk, cable, backplane slot or HBA.
- CHECKSUM errors: a bad sector returning wrong data, a flaky cable or controller, or (rarely) bad RAM.
- Errors on every disk at once: shared component (HBA, PSU, RAM) rather than a disk.

**First three commands.**
1. `zpool status -v tanks`
2. `sudo smartctl -a /dev/disk/by-id/<device>`
3. `sudo dmesg -T | grep -i -E 'blk_update_request|I/O error|mpt2sas|mpt3sas|medium error' | tail -30`

**Fix.**
1. Find out which disk and which counter (step 1).
2. Run `sudo zpool scrub tanks` so ZFS repairs bad blocks from parity.
3. If the disk looks healthy and the counters do not grow again, reset them with `sudo zpool clear tanks`. The alert clears when all counters are zero, so clearing is also your acknowledgement.
4. If the counters grow again, or SMART reports problems, replace the disk: `sudo zpool replace tanks <old-device> /dev/disk/by-id/<new-device>`, and update `zfsRaidz1Pool.devices`.

**Notes.** Counters are not cleared automatically. Errors on the `raidz1-0` or `tanks` rows (not on a disk row) mean ZFS could not repair something, which is more serious.

**Escalate when.** More than one disk shows errors, errors return after a clear, or ZpoolDataErrors fires. On RAIDZ1, a disk with errors on a degraded pool is a data-loss risk: back up first.

**Related alerts.** ZpoolDataErrors, ZpoolNotOnline, ZpoolScrubErrors, SMARTErrorLogGrowing, SMARTSectorsGrowing, SCSIUncorrectedErrors, SCSIDefectsGrowing.
