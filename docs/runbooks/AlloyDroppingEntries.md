# AlloyDroppingEntries

**What it means.** Alloy has been dropping log entries because it could not deliver them to Loki, for 10 minutes.

**Likely causes.** Loki is down, restarting or not ready; Loki is rejecting writes (see LokiDiscardingSamples); the network path or `lokiUrl` is wrong; `/data` is full.

**First three commands.**
1. `systemctl status alloy loki`
2. `curl -s localhost:3100/ready` and `curl -s localhost:12345/metrics | grep loki_write_dropped`
3. `journalctl -u alloy -n 50 --no-pager`

**Fix.** Restore Loki, then restart `alloy` if it does not recover on its own. Check `df -h /data` for space.

**Escalate when.** Loki is healthy but Alloy keeps dropping entries.

**Related alerts.** LokiDiscardingSamples, ServiceDown, CriticalDiskSpace.
