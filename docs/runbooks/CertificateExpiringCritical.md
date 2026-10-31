# CertificateExpiringCritical
**What it means.** A probed certificate expires within 7 days.
**First three commands.**
1. `echo | openssl s_client -connect <host>:443 2>/dev/null | openssl x509 -noout -dates`
2. `journalctl -u acme-<domain>.service -n 50 --no-pager`
3. `systemctl list-timers | grep acme`
**Fix.** Check the ACME renewal and port 80 reachability; force with `sudo systemctl start acme-<domain>.service`.
