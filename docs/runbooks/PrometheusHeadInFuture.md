# PrometheusHeadInFuture
**What it means.** The newest sample in the TSDB head is more than an hour ahead of now; new samples will be rejected.
**Likely causes.** The clock was ahead and then corrected.
**First three commands.**
1. `curl -s localhost:9090/api/v1/status/tsdb | jq '.data.headStats.maxTime/1000 - now'`
2. `ls /data/prometheus/data`
3. `systemctl status prometheus-tsdb-guard`
**Fix.** Let the guard run, or stop prometheus and move `data/wal` and `data/chunks_head` aside. If already-compacted blocks hold future samples, delete only those block directories (`promtool tsdb list /data/prometheus/data` shows time ranges) after copying them elsewhere.
**Escalate when.** Several blocks are affected: restore from your backup of `/data/prometheus` if you have one, or accept the data loss.
**Related.** PrometheusNoRecentSamples, ClockDrift, ClockNotSynced.
