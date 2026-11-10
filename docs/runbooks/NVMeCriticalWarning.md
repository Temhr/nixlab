# NVMeCriticalWarning

**What it means.** An NVMe drive's controller has raised a critical-warning flag: spare capacity is low, the temperature is out of range, reliability is degraded, the drive went read-only, or its volatile memory backup failed.

**Likely causes.** The drive is at end of life; overheating; a hardware fault.

**First three commands.**
1. `sudo nvme smart-log /dev/<device>` (the `critical_warning` value; use `nix shell nixpkgs#nvme-cli` if needed)
2. `sudo smartctl -a /dev/<device>`
3. `mount | grep <device>` (is it read-only?)

**Fix.** Back up now and replace the drive. If the flag is only the temperature bit, fix cooling first (see NVMeCriticalTemperature).

**Escalate when.** Always, unless it is only a temporary temperature flag that has cleared.

**Related alerts.** NVMeSpareLow, NVMeMediaErrors, NVMeCriticalTemperature, SMARTStatusFailed.
