# LokiDiscardingSamples

**What it means.** Loki is rejecting log lines (the `reason` label says why), for 10 minutes. Those logs are lost.

**Likely causes.**
- `rate_limited` / `per_stream_rate_limited`: a source logging faster than the limits (4 MB/s overall, 3 MB/s per stream).
- Samples that are too old: Alloy replaying a backlog or a clock jump (anything older than 168 h is rejected).
- Lines or label sets that exceed size limits.

**First three commands.**
1. `curl -s localhost:3100/metrics | grep loki_discarded_samples_total`
2. `journalctl -u loki -n 50 --no-pager`
3. In Grafana Explore: `topk(5, sum by (unit) (count_over_time({job="systemd-journal"}[5m])))` to find the noisiest source

**Fix.** Silence or fix the chatty source (a service in a crash loop is common), or raise the limits in the Loki module if the volume is legitimate.

**Escalate when.** Discards continue after the noisy source is fixed, or the reason is `greater_than_max_sample_age` right after a clock correction.

**Related alerts.** AlloyDroppingEntries, ClockDrift.
