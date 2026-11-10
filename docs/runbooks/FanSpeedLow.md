# FanSpeedLow

**What it means.** A fan that normally runs faster than 1500 RPM is now below 1000 RPM while the system is above 55 °C.

**Likely causes.** A failing or dust-clogged fan; a loose connector; a BIOS or fan-control setting change.

**First three commands.**
1. `sensors` (fan RPM and temperatures)
2. `sudo dmesg -T | grep -i -E 'fan|thermal' | tail`
3. `top -bn1 | head -15` (is it simply under heavy load?)

**Fix.** Clean the fan and vents, check that it spins freely and is plugged in, and review fan curves in the BIOS. Replace the fan if it is failing.

**Escalate when.** Temperatures keep rising, or CPU/NVMe temperature alerts fire at the same time.

**Related alerts.** HighCPUTemperature, CriticalCPUTemperature, NVMeHighTemperature, CPUThrottling.
