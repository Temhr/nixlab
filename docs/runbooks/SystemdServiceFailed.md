# SystemdServiceFailed

**What it means.** A systemd service or timer unit (the `name` label) has been in the failed state for 5 minutes.

**Likely causes.** A crash or non-zero exit; a missing dependency or mount; a bad configuration after a rebuild; a one-shot job that reported a problem on purpose.

**First three commands.**
1. `systemctl status <name>`
2. `journalctl -u <name> -n 50 --no-pager`
3. `systemctl list-units --failed`

**Fix.** Read the journal, correct the cause, then `sudo systemctl restart <name>` (or `sudo systemctl reset-failed <name>` once it is resolved or can be ignored).

**Notes.** On `nixnas1`, a failing `zfs-member-reconcile` or `zfs-integrity-metrics` unit means the ZFS metrics have stopped updating, so the ZFS member and integrity alerts will not fire. Treat those as urgent. `zfs-pool-rename` can fail at boot if a pool disk is missing, because its device fingerprint no longer matches.

**Escalate when.** The failed unit is boot-critical (`nfs-server`, `zfs-import-*`, `prometheus`, `alertmanager`) or many units fail at once.

**Related alerts.** ServiceDown, HostDown, ZpoolNotOnline.
