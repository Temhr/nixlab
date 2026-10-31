# SMARTStatusFailed
**What it means.** A drive's own SMART self-assessment says it is failing.
**First three commands.**
1. `sudo smartctl -a /dev/<device>`
2. `sudo smartctl -t long /dev/<device>`
3. `zpool status -x` (nixnas1)
**Fix.** Back up, replace the drive.
**Escalate when.** Always. Do not wait for the next alert.
