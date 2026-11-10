# ZpoolMemberMissing

**What it means.** A disk configured in `zfsRaidz1Pool.devices` no longer exists under `/dev/disk/by-id/`. The operating system has lost the disk, regardless of what ZFS reports; the alert is driven by `zfs_expected_device_present`, written by `zfs-member-reconcile` every 30 seconds.

**Likely causes.** The disk was pulled or came loose; a backplane slot, cable or HBA fault; the drive died or lost power; a disk was replaced but the Nix `devices` list was not updated.

**First three commands.**
1. `ls -l /dev/disk/by-id/ | grep <device>` (the `device` label of the alert)
2. `sudo dmesg -T | grep -i -E 'mpt2sas|mpt3sas|removing handle|enclosure' | tail -30`
3. `zpool status tanks`

**Fix.**
- Reseat the disk in its slot (dmesg shows the enclosure slot, for example `slot(7)`). If it reappears and spins up, `zfs-member-reconcile` runs `zpool online` for it within about 30 seconds and the alert resolves. `journalctl -t zfs-member-reconcile --since -1h` shows what it did.
- The disk does not come back: it has failed. `sudo zpool replace tanks <old-device> /dev/disk/by-id/<new-device>`, then update `zfsRaidz1Pool.devices` in `m720q-nas1.nix` and rebuild. Otherwise this alert keeps firing for the old name, and the `zfs-pool-rename` device fingerprint stops matching on the next boot.
- A replacement was already done and only the config is stale: update `devices` and rebuild.

**Notes.** `zpool status` may still say ONLINE for a removed disk until I/O reaches it (a scrub or normal reads). Trust this alert over the pool state in that window.

**Escalate when.** Two or more disks are missing (the pool is unavailable on RAIDZ1), or the pool is already DEGRADED for another reason. Back up what you can before touching anything.

**Related alerts.** ZpoolNotOnline, ZpoolMemberReonlined, ZpoolDeviceErrors, KernelFilesystemError.
