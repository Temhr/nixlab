# DNSResolutionFailure

**What it means.** A blackbox DNS probe (the `instance` label is the DNS server) has failed to resolve the test name for 3 minutes.

**Likely causes.** The DNS server is unreachable or down; internet connectivity is lost; a firewall change; the probed query name is wrong.

**First three commands.**
1. `dig @<instance> example.com +short` (use your configured `dnsQueryName`)
2. `resolvectl status`
3. `curl -s 'localhost:9115/probe?module=dns_a&target=<instance>&debug=true'`

**Fix.** Restore connectivity, or switch to a working server (the base config uses 9.9.9.9 and 1.1.1.1). If only one server fails, remove or replace it in `maintenance.exporters.blackbox.dnsTargets`.

**Escalate when.** All DNS targets fail; the host or the whole network has lost connectivity.

**Related alerts.** ProbeFailed, HighNetworkLatency, ClockNotSynced.
