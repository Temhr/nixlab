# ProbeFailed

**What it means.** A blackbox probe (HTTP, HTTP-insecure, ICMP or TCP) has failed for 5 minutes. The `instance` label is the probed target and `job` says which kind of probe.

**Likely causes.** The target host or service is down; a firewall or routing change; DNS failure; the local network is down (check whether the gateway probe is also failing).

**First three commands.**
1. `ping -c3 <target>` (ICMP) or `nc -zv <host> <port>` (TCP) or `curl -svI <url>` (HTTP)
2. `curl -s 'localhost:9115/probe?module=<module>&target=<target>&debug=true'`
3. `systemctl status prometheus-blackbox-exporter`

**Fix.** Depends on the probe: restart the target service, fix the firewall or DNS, or correct the target list in `services.prometheus-nixlab.maintenance.exporters.blackbox.*` if the target was retired.

**Escalate when.** The gateway probe fails (the whole network may be down), or several targets fail at once.

**Related alerts.** HostDown, ServiceDown, SSLProbeFailed, HighNetworkLatency, DNSResolutionFailure.
