# NVMeMediaErrors

**What it means.** The count of unrecovered media and data integrity errors on an NVMe drive increased during the last 7 days.

**Likely causes.** NAND cells wearing out or failing; a drive firmware fault; occasionally a power or connection problem.

**First three commands.**
1. `sudo smartctl -a /dev/<device>`
2. `sudo nvme smart-log /dev/<device>` (use `nix shell nixpkgs#nvme-cli` if it is not installed)
3. `sudo journalctl -k --since -7d | grep -i nvme`

**Fix.** Back up the drive's contents now and plan a replacement. Check for a firmware update from the vendor.

**Escalate when.** The counter keeps increasing, or NVMeCriticalWarning or NVMeSpareLow fires. Replace the drive immediately.

**Related alerts.** NVMeSpareLow, NVMeWearHigh, NVMeCriticalWarning, SMARTStatusFailed.
