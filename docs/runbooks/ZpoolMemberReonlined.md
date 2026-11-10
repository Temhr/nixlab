# ZpoolMemberReonlined

**What it means.** `zfs-member-reconcile` found a disk that had come back at the OS level while ZFS still listed it as REMOVED or UNAVAIL, and ran `zpool online` on it automatically. The alert stays for one hour after the last automatic action so a disk that keeps dropping out does not go unnoticed.

**Likely causes.** You pulled and reseated a disk on purpose; a loose cable or backplane slot; a flaky drive or HBA that resets intermittently; a power-saving or firmware glitch.

**First three commands.**
1. `journalctl -t zfs-member-reconcile --since -24h`
2. `zpool status -v tanks`
3. `sudo dmesg -T | grep -i -E 'mpt2sas|mpt3sas|removing handle|Power-on or device reset' | tail -50`

**Fix.** If you did it deliberately, nothing is needed; wait for the resilver to finish (`zpool status`) and the alert clears an hour later. If you did not:
- Reseat the disk and its cable/slot, and move it to another slot if the problem follows the slot rather than the drive.
- Check the disk: `sudo smartctl -x /dev/disk/by-id/<device>`.
- After the resilver, run `sudo zpool scrub tanks` to confirm there is no hidden damage.

**Notes.** Re-onlining is rate-limited to once per disk per 5 minutes. A disk that is repeatedly dropped and re-onlined will resilver each time, which is hard on the remaining disks.

**Escalate when.** It fires more than once in a week for the same disk, or ZpoolDeviceErrors, SMARTErrorLogGrowing or SCSIUncorrectedErrors fire for it. Replace the drive or fix the slot rather than relying on auto-recovery.

**Related alerts.** ZpoolMemberMissing, ZpoolNotOnline, ZpoolDeviceErrors, SMARTErrorLogGrowing, SCSIUncorrectedErrors.
