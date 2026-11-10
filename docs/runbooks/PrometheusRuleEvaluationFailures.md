# PrometheusRuleEvaluationFailures

**What it means.** Some alert or recording rules are failing to evaluate. A rule that errors does not fire, so the problem it watches for can go unnoticed.

**Likely causes.** A rule with a bad expression after a metric's labels changed (for example many-to-many matching); a query hitting too many series; a recent edit to `maintenance-alerts.nix`.

**First three commands.**
1. `curl -s localhost:9090/api/v1/rules | jq '[.data.groups[].rules[] | select(.health != "ok") | {name, lastError}]'`
2. `journalctl -u prometheus --since -1h --no-pager | grep -i rule`
3. `promtool check rules /data/prometheus/rules/alerts.yml`

**Fix.** Correct the failing expression in `maintenance-alerts.nix`, add or update its test in `rules.test.yml`, run `nix flake check`, and rebuild.

**Escalate when.** Many rules fail at once (check for Prometheus resource exhaustion or a TSDB problem).

**Related alerts.** PrometheusConfigReloadFailed, PrometheusNoRecentSamples.
