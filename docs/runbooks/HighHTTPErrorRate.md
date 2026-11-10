# HighHTTPErrorRate

**What it means.** More than 5% of requests to a Traefik service (the `service` label) are returning 5xx errors, with at least some real traffic. This alert only exists when the Traefik integration is enabled.

**Likely causes.** The backend service is down, crashing or overloaded; a bad deployment; a database or dependency failure behind it.

**First three commands.**
1. `journalctl -u traefik -n 50 --no-pager`
2. `curl -s localhost:8082/metrics | grep 'traefik_service_requests_total' | grep 'code="5'`
3. `systemctl status <backend service>` and its journal

**Fix.** Restore the backend (restart, roll back the last change), and check its dependencies. Verify with a request through Traefik.

**Escalate when.** The error rate is near 100% or affects several services (suspect Traefik or the network).

**Related alerts.** ServiceDown, ProbeFailed, SystemdServiceFailed.
