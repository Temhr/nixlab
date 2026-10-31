# ServiceDown
**What it means.** A scrape target other than Prometheus and the node exporter does not answer.
**First three commands.**
1. `systemctl status <job>`
2. `journalctl -u <job> -n 50 --no-pager`
3. `curl -s localhost:<port>/-/ready` (or the service's health endpoint)
**Fix.** Restart it; read the journal for the cause.
