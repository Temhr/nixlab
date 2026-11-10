# NetworkInterfaceErrors

**What it means.** A network interface has had more than 10 receive or transmit errors per second for 5 minutes.

**Likely causes.** A bad or loose cable; a failing switch port or NIC; a speed/duplex negotiation problem; on Wi-Fi hosts, poor signal.

**First three commands.**
1. `ip -s link show <device>`
2. `ethtool -S <device> | grep -i -E 'err|crc|drop'` and `ethtool <device>` (check negotiated speed and duplex)
3. `sudo dmesg -T | grep -i <device> | tail -20` (link flaps)

**Fix.** Reseat or replace the cable, try another switch port, and confirm the link negotiates the expected speed (for example 1000 Mb/s full on `eno1`). For Wi-Fi, check signal strength and consider moving the host to a wired link.

**Escalate when.** Errors continue on a known-good cable and port (suspect the NIC), or the link drops repeatedly.

**Related alerts.** NetworkPacketDrops, HighNetworkLatency, ProbeFailed.
