# SCSIDefectsGrowing

**What it means.** A SAS/SCSI drive added entries to its grown defect list in the last 7 days: it has found bad sectors and remapped them. On `nixnas1` these are the disks in the ZFS pool.

**Likely causes.** Media wearing out or a failing head; occasionally vibration or power problems.

**First three commands.**
1. `sudo smartctl -a /dev/<device>` (check "Elements in grown defect list" and the error counter log)
2. `zpool status -v tanks`
3. `sudo smartctl -t long /dev/<device>` (then read the result later with `smartctl -l selftest`)

**Fix.** A single small increase may be tolerable, but keep watching it. Make sure a recent scrub was clean (`zpool scrub tanks`), and replace the drive if the list keeps growing.

**Escalate when.** The count grows quickly (several per day), or SCSIUncorrectedErrors, ZpoolDeviceErrors or SMARTStatusFailed fires for the same drive. On a RAIDZ1 pool, replace it before a second disk has problems.

**Related alerts.** SCSIUncorrectedErrors, SMARTStatusFailed, ZpoolDeviceErrors, ZpoolNotOnline.
