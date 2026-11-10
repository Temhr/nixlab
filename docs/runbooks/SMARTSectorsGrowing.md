# SMARTSectorsGrowing

**What it means.** A drive's Reallocated_Sector_Ct, Current_Pending_Sector or Offline_Uncorrectable raw value grew in the last 7 days (the `attribute_name` label says which): the drive is wearing out.

**Likely causes.** Failing platter surface or flash cells, usually progressive.

**First three commands.**
1. `sudo smartctl -A /dev/<device> | grep -E 'Reallocated|Pending|Uncorrectable'`
2. `sudo smartctl -t long /dev/<device>`
3. `zpool status -v tanks` (if the disk is in a pool)

**Fix.** Back up the data and plan a replacement. Pending sectors sometimes clear after being overwritten, but treat any growth as a warning that the drive is on its way out.

**Escalate when.** Growth continues, the values climb quickly, or SMARTStatusFailed fires. Replace the drive.

**Related alerts.** SMARTErrorLogGrowing, SMARTStatusFailed, ZpoolDeviceErrors.
