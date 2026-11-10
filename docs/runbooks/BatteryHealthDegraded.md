# BatteryHealthDegraded

**What it means.** A battery holds less than 60% of its design capacity, for an hour.

**Likely causes.** Normal wear after many charge cycles; heat; keeping the battery at 100% while permanently plugged in.

**First three commands.**
1. `upower -i $(upower -e | grep -i BAT)`
2. `cat /sys/class/power_supply/BAT0/{energy_full,energy_full_design,cycle_count}`
3. `cat /sys/class/power_supply/BAT0/status`

**Fix.** Plan a battery replacement. To slow further wear on a mostly-plugged-in laptop, set a charge limit (for example 60 to 80%) through the firmware or your power-management tool.

**Escalate when.** The battery swells or the case bulges: stop using and charging it immediately.

**Related alerts.** None.
