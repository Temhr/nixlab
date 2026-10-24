#!/usr/bin/env bash
# Runtime verification for the nixlab monitoring stack. Run ON the host.
# Env: MON_HOST (default 127.0.0.1), MON_*_PORT, MON_UNITS, MON_NTFY_AUTH (user:pass), MON_TOPIC
set -u
H=${MON_HOST:-127.0.0.1}
P=${MON_PROM_PORT:-9090}; L=${MON_LOKI_PORT:-3100}; G=${MON_GRAFANA_PORT:-3101}
A=${MON_AM_PORT:-9093};   N=${MON_NTFY_PORT:-2586}; T=${MON_TOPIC:-alerts}
UNITS=${MON_UNITS:-"prometheus loki alloy grafana alertmanager ntfy prometheus-node-exporter"}
fail=0
ok(){ printf '  \033[32mOK\033[0m   %s\n' "$1"; }
bad(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=1; }
check(){ local n=$1; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else bad "$n"; fi; }
cu(){ curl -fsS --max-time 5 "$@"; }

echo "units";     for u in $UNITS; do check "$u active" systemctl is-active --quiet "$u"; done
echo "endpoints"
check "prometheus ready"   cu "http://$H:$P/-/ready"
check "loki ready"         cu "http://$H:$L/ready"
check "alertmanager ready" cu "http://$H:$A/-/ready"
check "grafana health"     cu "http://$H:$G/api/health"
check "ntfy health"        cu ${MON_NTFY_AUTH:+-u "$MON_NTFY_AUTH"} "http://$H:$N/v1/health"
echo "prometheus"
down=$(cu "http://$H:$P/api/v1/targets" | jq '[.data.activeTargets[]|select(.health!="up")]|length') || down=-1
[ "$down" = 0 ] && ok "all scrape targets up" || bad "scrape targets not up: $down"
badrules=$(cu "http://$H:$P/api/v1/rules" | jq '[.data.groups[].rules[]|select(.health!="ok")]|length') || badrules=-1
[ "$badrules" = 0 ] && ok "all rules healthy" || bad "rules unhealthy: $badrules"
ams=$(cu "http://$H:$P/api/v1/alertmanagers" | jq '.data.activeAlertmanagers|length') || ams=0
[ "${ams:-0}" -ge 1 ] && ok "alertmanager discovered" || bad "prometheus sees no alertmanager"
echo "loki"
check "loki has labels" bash -c "curl -fsS http://$H:$L/loki/api/v1/labels | jq -e '.data|length>0'"

if [ "${1:-}" = "--fire-test" ]; then
  echo "end-to-end alert path"
  now=$(date -u +%FT%TZ); end=$(date -u -d '+3 min' +%FT%TZ)
  cu -XPOST "http://$H:$A/api/v2/alerts" -H 'Content-Type: application/json' \
    -d "[{\"labels\":{\"alertname\":\"MonCheckTest\",\"severity\":\"warning\",\"instance\":\"moncheck\"},\"startsAt\":\"$now\",\"endsAt\":\"$end\"}]" \
    && ok "alert posted" || bad "post failed"
  for _ in $(seq 1 18); do
    if cu ${MON_NTFY_AUTH:+-u "$MON_NTFY_AUTH"} "http://$H:$N/$T/json?poll=1&since=5m" | grep -q MonCheckTest; then
      ok "alert reached ntfy"; exit $fail; fi
    sleep 5
  done
  bad "alert did NOT reach ntfy within 90s"
fi
exit $fail
