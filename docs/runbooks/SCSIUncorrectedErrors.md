# SCSIUncorrectedErrors

**What it means.** A SAS/SCSI drive reported more uncorrected read or write errors in the last 7 days: data the drive could not recover by itself.

**Likely causes.** Failing media; a failing head; a bad connection, cable, or backplane slot.

**First three commands.**
1. `sudo smartctl -a /dev/<device>` (the "Error counter log" table)
2. `zpool status -v tanks`
3. `sudo dmesg -T | grep -i -E 'mpt2sas|mpt3sas|medium error|I/O error' | tail -30`

**Fix.** On a ZFS pool, the data is normally repaired from parity; run `sudo zpool scrub tanks` and watch ZpoolDeviceErrors. Check the cable and slot, and replace the drive if the counters keep rising.

**Escalate when.** The pool is already degraded, errors appear on more than one drive, or SMARTStatusFailed fires.

**Related alerts.** SCSIDefectsGrowing, ZpoolDeviceErrors, ZpoolDataErrors, SMARTStatusFailed.
