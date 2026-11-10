# CPUThrottling

**What it means.** One or more CPU cores have been running below 60% of their maximum frequency while busy (over 50% usage) for 10 minutes, and the host is not on battery. The CPU is slower than it should be.

**Likely causes.** Thermal throttling (see CPU temperature alerts); a power profile or governor limiting the frequency; a power limit set in firmware; a weak or wrong power adapter on a laptop.

**First three commands.**
1. `grep MHz /proc/cpuinfo | sort | uniq -c | head` and `cpupower frequency-info`
2. `sensors`
3. `sudo journalctl -k --since -1h | grep -i -E 'throttl|thermal|powercap'`

**Fix.** If the machine is hot, fix cooling first. Otherwise check the CPU governor and power profile (`powerprofilesctl get`, TLP or `powerManagement.cpuFreqGovernor` in your NixOS config) and the power adapter.

**Escalate when.** It persists with cool temperatures and a performance governor (suspect firmware limits or hardware).

**Related alerts.** HighCPUTemperature, CriticalCPUTemperature, FanSpeedLow, HighCPULoad.
