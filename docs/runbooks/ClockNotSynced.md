# ClockNotSynced

**What it means.** The kernel reports that the system clock is not synchronized with an NTP source, and has for 15 minutes.

**Likely causes.** No network or DNS; NTP blocked by a firewall; `systemd-timesyncd` not running; a freshly booted offline laptop.

**First three commands.**
1. `timedatectl` (look at "System clock synchronized")
2. `systemctl status systemd-timesyncd systemd-time-wait-sync`
3. `ping -c3 pool.ntp.org` (or check DNS with `resolvectl query pool.ntp.org`)

**Fix.** Restore network and DNS, `sudo systemctl restart systemd-timesyncd`, and confirm `timedatectl` shows the clock as synchronized. The base profile makes Prometheus, Loki and Alloy wait for `time-sync.target` for this reason.

**Escalate when.** It persists on a networked host (suspect timesyncd configuration), or ClockDrift fires as well.

**Related alerts.** ClockDrift, PrometheusSamplesOutOfBounds, PrometheusNoRecentSamples.
