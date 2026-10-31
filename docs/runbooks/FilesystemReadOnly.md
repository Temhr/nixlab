# FilesystemReadOnly
**What it means.** The kernel remounted a filesystem read-only, normally after I/O errors.
**First three commands.**
1. `dmesg -T | grep -i -E 'error|remount|I/O'`
2. `smartctl -a /dev/<disk>`
3. `mount | grep ' ro,'`
**Fix.** Back up what you can now, then `fsck` from rescue media and replace the disk if SMART agrees.
**Escalate when.** Always: treat as a failing disk until proven otherwise.
**Related.** SMARTStatusFailed, KernelFilesystemError.
