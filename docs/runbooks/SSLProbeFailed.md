# SSLProbeFailed

**What it means.** The TLS probe for an endpoint has failed for 10 minutes: the handshake or HTTP check did not succeed. While it fails, the certificate expiry alerts cannot evaluate for that endpoint.

**Likely causes.** The service is down; the certificate expired or does not match the name; a TLS configuration change; DNS or firewall problems.

**First three commands.**
1. `curl -svI <target> 2>&1 | head -30`
2. `echo | openssl s_client -connect <host>:443 -servername <host> 2>/dev/null | openssl x509 -noout -dates -subject`
3. `curl -s 'localhost:9115/probe?module=http_2xx&target=<target>&debug=true'`

**Fix.** Restore the service, renew or fix the certificate (see CertificateExpiringCritical for ACME checks), or correct the target in the blackbox `sslTargets` list if it was retired.

**Escalate when.** Several endpoints fail at once (a shared proxy or network problem).

**Related alerts.** ProbeFailed, CertificateExpiringSoon, CertificateExpiringCritical.
