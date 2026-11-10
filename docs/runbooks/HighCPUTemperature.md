# HighCPUTemperature

**What it means.** A CPU sensor (coretemp, k10temp or amdgpu) has been between 80 and 90 °C for 5 minutes. Above 90 °C the critical alert (CriticalCPUTemperature) takes over.

**Likely causes.** Sustained heavy load; dust or dried thermal paste; a slow or failed fan; blocked airflow; a hot room (common on laptops).

**First three commands.**
1. `sensors`
2. `top -bn1 | head -15` (what is using the CPU?)
3. `systemctl status thermald` (if you run it) and `journalctl -k | grep -i -E 'thermal|throttl' | tail`

**Fix.** Reduce the load, clear dust from fans and heatsinks, check that the fans spin, and improve ventilation. On laptops, use a cooler power profile. Re-paste the CPU if it has been several years.

**Escalate when.** Temperature keeps climbing toward 90 °C, or the CPU starts throttling (CPUThrottling).

**Related alerts.** CriticalCPUTemperature, CPUThrottling, FanSpeedLow.
