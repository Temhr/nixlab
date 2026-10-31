# AlertmanagerNotifyFailing
**What it means.** Alertmanager cannot deliver to a receiver: alerts are not reaching you.
**First three commands.**
1. `journalctl -u alertmanager -n 50 --no-pager`
2. `curl -s localhost:9093/metrics | grep alertmanager_notifications_failed_total`
3. `MON_NTFY_AUTH=reader:<pw> bin/mon-check.sh --fire-test`
**Fix.** Usually ntfy is down or the credentials in the alertmanager secrets file are wrong (NTFY_ALERTMANAGER_PASSWORD).
**Escalate when.** ntfy is healthy and the credentials are right but `alertmanager_notifications_failed_total` keeps rising.
