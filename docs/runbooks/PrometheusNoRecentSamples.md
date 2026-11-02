# PrometheusNoRecentSamples
**What it means.** Prometheus recorded no sample for itself in 10 minutes: it is running but not storing.
**Likely causes.** Clock jump (TSDB head in the future); disk full; WAL corruption.
**First three commands.**
1. `journalctl -u prometheus -n 50 --no-pager | grep -i -E 'out of bounds|error'`
2. `curl -s localhost:9090/api/v1/status/tsdb | jq '.data.headStats | {minTime, maxTime}'; date +%s`
3. `timedatectl; df -h /data`
**Fix.** Correct the clock first (`timedatectl set-ntp true`). `prometheus-tsdb-guard` quarantines the WAL automatically (up to 6-hourly); to do it by hand: stop prometheus, move `data/wal` and `data/chunks_head` aside, start it.
**Escalate when.** Blocks on disk already contain future timestamps: see PrometheusHeadInFuture.
**Related.** PrometheusHeadInFuture, PrometheusSamplesOutOfBounds, ClockDrift.
