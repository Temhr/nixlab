# ZpoolNotOnline

**What it means.** ZFS itself reports a pool in a state other than ONLINE (DEGRADED, FAULTED, SUSPENDED, ...). On a RAIDZ1 pool, DEGRADED means one disk's worth of redundancy is already gone.

**Likely causes.** A member disk was removed, failed, or was marked UNAVAIL/REMOVED after I/O errors; a cable, backplane slot or HBA problem; a disk taken OFFLINE by hand.

**First three commands.**
1. `zpool status -v tanks`
2. `sudo dmesg -T | grep -i -E 'mpt2sas|mpt3sas|I/O error' | tail -30`
3. `zpool events -v | tail -60`

**Fix.** Identify the non-ONLINE disk in `zpool status`.
- Disk present again (`ls -l /dev/disk/by-id | grep <device>`) but ZFS still shows REMOVED/UNAVAIL: `sudo zpool online tanks <device>`. `zfs-member-reconcile` does this automatically within about 30 seconds.
- Disk dead: `sudo zpool replace tanks <old-device> /dev/disk/by-id/<new-device>`, then update `zfsRaidz1Pool.devices` in `m720q-nas1.nix` so the member checks and the pool-rename fingerprint match the new disk.
- Disk OFFLINE on purpose: `sudo zpool online tanks <device>`.

Wait for the resilver to finish (`zpool status`) before anything else that stresses the pool.

**Notes.** ZFS only updates pool state when I/O reaches the failed disk, and ZED does not process removal events on this host. A removed disk on an idle pool can show ONLINE for a long time; `ZpoolMemberMissing` covers that gap.

**Escalate when.** A second disk shows errors or goes missing while the pool is degraded (RAIDZ1 cannot survive that), or the state is FAULTED/SUSPENDED. Stop, back up what you can, and do not reboot.

**Related alerts.** ZpoolMemberMissing, ZpoolMemberReonlined, ZpoolDeviceErrors, SMARTStatusFailed, KernelFilesystemError.
