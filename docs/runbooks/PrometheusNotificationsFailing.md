# PrometheusNotificationsFailing

**What it means.** Prometheus is getting errors when sending alerts to Alertmanager (the `alertmanager` label shows which one), and has for 10 minutes.

**Likely causes.** Alertmanager is down, restarting, or not listening where Prometheus expects it (for example after a `listenAddress` change).

**First three commands.**
1. `curl -s localhost:9090/metrics | grep prometheus_notifications_errors_total`
2. `curl -s localhost:9093/-/ready`
3. `journalctl -u prometheus -n 50 --no-pager | grep -i notif`

**Fix.** Restore Alertmanager (`systemctl status alertmanager`, `journalctl -u alertmanager -n 50`) and confirm `alertmanagerTargets` matches the address and port it binds to.

**Escalate when.** Alertmanager is healthy and reachable by `curl` but errors keep growing.

**Related alerts.** PrometheusNoAlertmanager, AlertmanagerNotifyFailing.
