# NVMeSpareLow

**What it means.** An NVMe drive's available spare capacity is below its own threshold. It has used up its reserve of replacement blocks and can fail without much more warning.

**Likely causes.** The drive is at end of life from wear, or many blocks have failed.

**First three commands.**
1. `sudo smartctl -a /dev/<device> | grep -i -E 'spare|percentage|warning|media'`
2. `sudo nvme smart-log /dev/<device>`
3. `lsblk` and `findmnt` (what lives on this drive?)

**Fix.** Back up now and replace the drive. Do not wait for another alert.

**Escalate when.** Always. Treat as imminent failure.

**Related alerts.** NVMeWearHigh, NVMeMediaErrors, NVMeCriticalWarning, SMARTStatusFailed.
