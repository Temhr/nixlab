# NVMeHighTemperature

**What it means.** An NVMe drive has been between 75 and 85 °C for 10 minutes. Above 85 °C the critical alert (NVMeCriticalTemperature) takes over.

**Likely causes.** Poor airflow or a dusty case; a missing heatsink; sustained heavy I/O; a failed fan; a hot ambient room.

**First three commands.**
1. `sensors` (look at the nvme chip's temperatures)
2. `sudo smartctl -a /dev/nvme0 | grep -i -E 'temperature|warning'`
3. `iostat -x 5 3` (what is writing to it?) and `top -bn1 | head -15`

**Fix.** Improve airflow, clean dust, fit or reseat a heatsink, and reduce the I/O load. Check FanSpeedLow in case a fan has failed.

**Escalate when.** Temperature keeps rising toward 85 °C, or throttling is visible (I/O suddenly slows).

**Related alerts.** NVMeCriticalTemperature, FanSpeedLow, CPUThrottling.
