# PrometheusNoAlertmanager

**What it means.** Prometheus has discovered no Alertmanager for 10 minutes. Alerts are still evaluated but cannot be delivered.

**Likely causes.** The `alertmanager` service is stopped or crashing; Prometheus's alerting config does not point at it.

**First three commands.**
1. `systemctl status alertmanager`
2. `curl -s localhost:9090/api/v1/alertmanagers | jq`
3. `curl -s localhost:9093/-/ready`

**Fix.** Start or fix Alertmanager (`journalctl -u alertmanager -n 50`). If it is running, check `alerting.alertmanagers` in `/data/prometheus/prometheus.yml` (the stack sets `127.0.0.1:9093`).

**Notes.** This alert is itself delivered through Alertmanager, so while Alertmanager is down you will not receive it on your phone. Check the Grafana dashboard (health score and alert table) and `curl -s localhost:9090/api/v1/alerts` to see what is actually firing.

**Escalate when.** Always treat as urgent: during this time no alert, including log-based ones, can reach you.

**Related alerts.** PrometheusNotificationsFailing, AlertmanagerNotifyFailing.
