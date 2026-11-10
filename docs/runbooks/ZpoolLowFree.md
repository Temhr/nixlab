# ZpoolLowFree

**What it means.** A ZFS dataset has had under 15% free space for 15 minutes. ZFS write performance and fragmentation get noticeably worse as a pool fills, and a full pool is hard to recover from.

**Likely causes.** Data growth; snapshots holding deleted data; a large reservation or refreservation; NFS clients writing more than expected.

**First three commands.**
1. `zfs list -o space -r tanks`
2. `zpool list -o name,size,alloc,free,frag,cap tanks`
3. `zfs list -t snapshot -o name,used -s used -r tanks | tail -20`

**Fix.** Delete or move data, destroy old snapshots (`sudo zfs destroy <dataset>@<snap>`), and check for reservations (`zfs get -r reservation,refreservation tanks`). Growing the pool means replacing every disk in the vdev with a larger one (resilver each in turn), since a RAIDZ1 vdev cannot be extended in place.

**Notes.** The alert uses the dataset view (`node_filesystem_*`), which is usable space after parity. `zpool list` shows raw capacity including parity, so its numbers look roomier than `zfs list`. The generic CriticalDiskSpace and DiskWillFillIn24h rules exclude ZFS, so this is the only space alert for the pool.

**Escalate when.** Free space is under 10%, or it is dropping faster than you can free it. Past about 90% full, write stalls and NFS client errors (ENOSPC) become likely.

**Related alerts.** None directly; see ZpoolNotOnline if a degraded pool is also being resilvered (resilvers need free space to complete cleanly).
