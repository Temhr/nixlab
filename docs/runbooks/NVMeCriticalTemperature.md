# NVMeCriticalTemperature

**What it means.** An NVMe drive has been above 85 °C for 5 minutes. The drive will throttle heavily and risks data errors or shutdown.

**Likely causes.** No heatsink or blocked airflow; a failed fan; sustained heavy I/O; a hot room.

**First three commands.**
1. `sensors` (the nvme chip) and `sudo smartctl -a /dev/<device> | grep -i -E 'temperature|warning'`
2. `iostat -x 5 3` and `sudo iotop -oPa` (find the heavy writer)
3. `sudo dmesg -T | grep -i nvme | tail -20`

**Fix.** Stop or pause the heavy I/O, improve airflow, and fit a heatsink if the drive has none. If the temperature does not drop quickly, shut the machine down.

**Escalate when.** Temperature keeps rising, the drive disconnects, or NVMeCriticalWarning fires.

**Related alerts.** NVMeHighTemperature, NVMeCriticalWarning, FanSpeedLow.
