# HostDown
**What it means.** This host's Prometheus has not been able to scrape its own node exporter for 5 minutes.
**Likely causes.** The exporter crashed or was stopped; it is out of tasks or memory; the unit is failing to start after a change.
**First three commands.**
1. `systemctl status prometheus-node-exporter`
2. `journalctl -u prometheus-node-exporter -n 50 --no-pager`
3. `curl -s localhost:9100/metrics | head -n5`
**Fix.** Restart the exporter; if it fails again, read the journal for the cause (a recent configuration change).
**Escalate when.** The exporter is up but Prometheus still reports the target down: check `curl -s localhost:9090/api/v1/targets`.
**Related.** ServiceDown.
