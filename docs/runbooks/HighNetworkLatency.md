# HighNetworkLatency

**What it means.** An ICMP probe's round-trip time to a target (the `instance` label) has been above 100 ms for 5 minutes.

**Likely causes.** Congested or weak link (especially Wi-Fi); a saturated uplink; a distant or overloaded target; routing problems.

**First three commands.**
1. `ping -c 20 <instance>`
2. `mtr -rw -c 20 <instance>`
3. `ip -s link show` (errors or drops on the local interface)

**Fix.** Find where the latency starts in `mtr`. For local targets, check the cable, switch port and Wi-Fi signal, and look for a big transfer saturating the link.

**Escalate when.** The latency also affects the gateway, or is accompanied by packet loss (ProbeFailed).

**Related alerts.** ProbeFailed, NetworkInterfaceErrors, NetworkPacketDrops.
