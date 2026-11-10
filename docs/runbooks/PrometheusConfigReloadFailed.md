# PrometheusConfigReloadFailed

**What it means.** The last attempt to reload Prometheus's configuration failed, so it is still running the older configuration or rules.

**Likely causes.** A bad generated config or rules file after a Nix change; a file ownership problem in `/data/prometheus`.

**First three commands.**
1. `promtool check config /data/prometheus/prometheus.yml`
2. `promtool check rules /data/prometheus/rules/alerts.yml`
3. `journalctl -u prometheus -n 50 --no-pager`

**Fix.** The config and rules are regenerated from Nix at every start, so correct the source (for example `maintenance-alerts.nix` or the scrape-config modules), run `nix flake check`, rebuild, and restart `prometheus`. Do not hand-edit the generated files.

**Escalate when.** A restart fails as well, which means Prometheus is down (see ServiceDown and PrometheusNoRecentSamples).

**Related alerts.** PrometheusRuleEvaluationFailures, ServiceDown.
