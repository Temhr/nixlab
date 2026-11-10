# ClockDrift

**What it means.** The system clock is more than 0.1 seconds away from the time the kernel believes is correct, for 10 minutes.

**Likely causes.** NTP is not reaching its servers (network, firewall, DNS); the time service is stopped; a failing RTC battery; a VM or suspend/resume jump.

**First three commands.**
1. `timedatectl` and `timedatectl timesync-status`
2. `systemctl status systemd-timesyncd`
3. `journalctl -u systemd-timesyncd -n 30 --no-pager`

**Fix.** Make sure the host can reach an NTP server, restart `systemd-timesyncd`, and use `sudo timedatectl set-ntp true`. A large drift can poison Prometheus's TSDB, so watch for PrometheusSamplesOutOfBounds.

**Escalate when.** The drift is large (seconds or more) or keeps returning (hardware clock problem).

**Related alerts.** ClockNotSynced, PrometheusSamplesOutOfBounds, PrometheusHeadInFuture.
