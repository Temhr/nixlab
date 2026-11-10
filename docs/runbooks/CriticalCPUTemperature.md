# CriticalCPUTemperature

**What it means.** A CPU sensor has been above 90 °C for 2 minutes. The CPU will throttle or the machine may shut itself down to protect the hardware.

**Likely causes.** A failed or stopped fan; a heatsink that has come loose; a runaway process pinning every core; heavily blocked airflow or a very hot room.

**First three commands.**
1. `sensors`
2. `top -bn1 | head -15`
3. `sudo dmesg -T | grep -i -E 'thermal|throttl|critical' | tail`

**Fix.** Stop or kill the heavy process, check that the fans are running, and improve cooling. If the temperature is not falling within a few minutes, shut the machine down and inspect it.

**Escalate when.** Always treat as urgent. Shut down rather than let it keep running at this temperature.

**Related alerts.** HighCPUTemperature, CPUThrottling, FanSpeedLow.
