# SMARTErrorLogGrowing

**What it means.** New entries appeared in a drive's SMART error log in the last 7 days.

**Likely causes.** Failing media; a bad or loose SATA cable (look for UDMA CRC errors); controller or power problems.

**First three commands.**
1. `sudo smartctl -l error /dev/<device>`
2. `sudo smartctl -A /dev/<device>` (check UDMA_CRC_Error_Count and the sector attributes)
3. `sudo smartctl -t short /dev/<device>` (then `smartctl -l selftest /dev/<device>`)

**Fix.** If the errors are CRC errors, reseat or replace the cable and watch whether they stop. If they are media errors, back up and replace the drive.

**Escalate when.** Errors keep growing, or SMARTSectorsGrowing or SMARTStatusFailed fires too.

**Related alerts.** SMARTSectorsGrowing, SMARTStatusFailed, SCSIUncorrectedErrors.
