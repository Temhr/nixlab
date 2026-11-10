# CertificateExpiringSoon

**What it means.** A probed TLS certificate expires in 7 to 30 days. Under 7 days the critical alert (CertificateExpiringCritical) takes over.

**Likely causes.** The automatic ACME renewal is failing or not running; a manually managed certificate nearing expiry.

**First three commands.**
1. `echo | openssl s_client -connect <host>:443 -servername <host> 2>/dev/null | openssl x509 -noout -dates`
2. `systemctl list-timers | grep acme` and `journalctl -u acme-<domain>.service -n 50 --no-pager`
3. `curl -sI http://<host>/.well-known/acme-challenge/` (is port 80 reachable?)

**Fix.** Fix the renewal (DNS or HTTP challenge reachability, rate limits), force it with `sudo systemctl start acme-<domain>.service`, or renew manually.

**Escalate when.** It drops under 7 days with renewal still failing.

**Related alerts.** CertificateExpiringCritical, SSLProbeFailed.
