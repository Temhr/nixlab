# FilesystemDeviceError

**What it means.** node_exporter could not read a filesystem's size for 5 minutes, usually because the mount is stale or the device is bad.

**Likely causes.** A stale NFS mount after the server went away; a device that disappeared or has I/O errors; a broken FUSE mount.

**First three commands.**
1. `findmnt` and `timeout 5 stat <mountpoint>` (a hang means a stale mount)
2. `sudo dmesg -T | grep -i -E 'nfs|I/O error|timeout' | tail -20`
3. `ping -c3 <nfs server>` and `systemctl status <mount unit>`

**Fix.** Restore the server or device, then remount. For a dead NFS mount, `sudo umount -fl <mountpoint>` and mount it again.

**Escalate when.** It is a local disk (suspect hardware: check SMART and ZFS status).

**Related alerts.** ExpectedMountMissing, FilesystemReadOnly, KernelFilesystemError.
