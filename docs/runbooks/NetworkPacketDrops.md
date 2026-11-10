# NetworkPacketDrops

**What it means.** The kernel is dropping more than 50 packets per second on an interface for 5 minutes. These are drops at the interface or queue level, not firewall rejections.

**Likely causes.** The host cannot keep up with traffic (CPU saturated, small receive ring); a traffic burst or loop on the network; a congested or misbehaving Wi-Fi link.

**First three commands.**
1. `ip -s -s link show <device>`
2. `ethtool -S <device> | grep -i -E 'drop|miss|fifo'`
3. `top -bn1 | head -15` (is the CPU busy?) and `cat /proc/pressure/cpu`

**Fix.** Find and stop the traffic source, free CPU, or raise the receive ring size (`ethtool -g <device>`, then `sudo ethtool -G <device> rx <n>`). Check the other end of the link for a flapping device or loop.

**Escalate when.** Drops persist with an idle CPU and a healthy cable, or are accompanied by NetworkInterfaceErrors.

**Related alerts.** NetworkInterfaceErrors, HighNetworkLatency, HighCPULoad.
