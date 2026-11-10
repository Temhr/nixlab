# ExpectedMountMissing

**What it means.** A mountpoint listed in `services.prometheus-nixlab.maintenance.expectedMounts` has no filesystem metrics for 5 minutes: it is not mounted, or the host is not reporting.

**Likely causes.** The mount failed at boot (disk or pool missing, failed unit); the ZFS pool did not import; a stale or removed mount; node_exporter is down.

**First three commands.**
1. `findmnt <mountpoint>` and `systemctl list-units --type=mount --state=failed`
2. `journalctl -b | grep -i <mountpoint> | tail -20`
3. `zpool status` (for `/mirror` on `nixnas1`) or `lsblk -f` (for other disks)

**Fix.** Start the mount unit (`sudo systemctl start <unit>`) or import the pool, and fix whatever stopped it. Make sure nothing keeps writing into the bare directory on the root disk while it is unmounted.

**Notes.** If the mount was removed on purpose, delete it from `expectedMounts`. If the whole host is silent, look at HostDown.

**Escalate when.** The disk or pool is missing at the hardware level (see ZpoolMemberMissing for ZFS hosts).

**Related alerts.** ZpoolNotOnline, ZpoolMemberMissing, FilesystemDeviceError, HostDown.
