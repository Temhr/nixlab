# NVMeWearHigh

**What it means.** An NVMe drive has used more than 80% of its rated write endurance.

**Likely causes.** Normal aging of a heavily written drive; a workload with high write volume (logs, databases, metrics, swap, build artifacts).

**First three commands.**
1. `sudo smartctl -a /dev/<device> | grep -i -E 'percentage used|data units written|spare'`
2. `iostat -x 5 3`
3. `sudo iotop -oPa` (what has written the most?)

**Fix.** Plan a replacement before the drive reaches 100%. Reduce write volume where you can: move heavy writers to another drive, lower log verbosity, or use `noatime` mounts.

**Escalate when.** Usage passes about 95%, or available spare starts dropping (NVMeSpareLow).

**Related alerts.** NVMeSpareLow, NVMeMediaErrors.
