#!/usr/bin/env bash
# Usage: bin/monitoring-smoke.sh [host]   (ports overridable via env)
set -u
H=${1:-127.0.0.1}
PROM=${PROM_PORT:-9090} AM=${AM_PORT:-9093} LOKI=${LOKI_PORT:-3100}
GRAF=${GRAFANA_PORT:-3101} NTFY=${NTFY_PORT:-2586}
rc=0
chk() { local n=$1; shift; if "$@" >/dev/null 2>&1; then printf '  ok    %s\n' "$n"; else printf '  FAIL  %s\n' "$n"; rc=1; fi; }

echo "health:"
chk "prometheus"   curl -fsS --retry 3 --retry-delay 3 --retry-all-errors "http://$H:$PROM/-/healthy"
chk "alertmanager" curl -fsS --retry 3 --retry-delay 3 --retry-all-errors "http://$H:$AM/-/healthy"
chk "loki"         curl -fsS --retry 3 --retry-delay 3 --retry-all-errors "http://$H:$LOKI/ready"
chk "grafana"      curl -fsS --retry 3 --retry-delay 3 --retry-all-errors "http://$H:$GRAF/api/health"
chk "ntfy"         curl -fsS --retry 3 --retry-delay 3 --retry-all-errors "http://$H:$NTFY/v1/health"

echo "targets (health / job / url):"
curl -fsS "http://$H:$PROM/api/v1/targets" \
  | jq -r '.data.activeTargets[] | "  \(.health)\t\(.labels.job)\t\(.scrapeUrl)"' | sort

echo "rule groups (name / rules / errors):"
curl -fsS "http://$H:$PROM/api/v1/rules" \
  | jq -r '.data.groups[] | "  \(.name)\t\(.rules|length)\t\([.rules[]|select(.health!="ok")]|length)"'

echo "alerts (state / name):"
curl -fsS "http://$H:$PROM/api/v1/alerts" \
  | jq -r '.data.alerts[] | "  \(.state)\t\(.labels.alertname)"' | sort | uniq -c

echo "loki labels:"
curl -fsS "http://$H:$LOKI/loki/api/v1/labels" | jq -c '.data'
exit $rc
