# PrometheusSamplesOutOfBounds

**What it means.** Prometheus is rejecting scraped samples as out of bounds, usually because the clock jumped and the TSDB head is out of line with real time. Stored data stops being reliable.

**Likely causes.** The clock was wrong (a fast RTC, no NTP at boot) and has since been corrected, or the host was suspended and resumed.

**First three commands.**
1. `timedatectl`
2. `journalctl -u prometheus --since -1h --no-pager | grep -i 'out of bounds'`
3. `curl -s localhost:9090/api/v1/status/tsdb | jq '.data.headStats | {minTime, maxTime}'; date +%s`

**Fix.** Correct the clock first (`timedatectl set-ntp true`). `prometheus-tsdb-guard` quarantines the WAL and head automatically when this persists; see PrometheusHeadInFuture and PrometheusNoRecentSamples for the manual steps.

**Escalate when.** It continues after the clock is right and the guard has run.

**Related alerts.** PrometheusHeadInFuture, PrometheusNoRecentSamples, ClockDrift, ClockNotSynced.
