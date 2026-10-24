#!/usr/bin/env bash
set -eu
out=${1:?usage: mon-snapshot.sh <outdir>}; mkdir -p "$out"
D=${MON_DATA:-/data}
for u in prometheus loki alloy grafana alertmanager ntfy prometheus-node-exporter; do
  systemctl cat "$u" 2>/dev/null | sed -E 's#/nix/store/[a-z0-9]{32}-#/nix/store/#g' > "$out/unit-$u.txt" || true
done
cp "$D/prometheus/prometheus.yml" "$out/prometheus.yml"  2>/dev/null || true
cp "$D/prometheus/rules/alerts.yml" "$out/alerts.yml"    2>/dev/null || true
cp "$D/loki/loki.yaml" "$out/loki.yaml"                  2>/dev/null || true
cp /var/lib/alloy/config.alloy "$out/config.alloy"       2>/dev/null || true
cp "$D/ntfy/server.yml" "$out/ntfy-server.yml"           2>/dev/null || true
curl -fsS localhost:9093/api/v2/status | jq -r .config.original > "$out/alertmanager.yml" 2>/dev/null || true
ss -tlnpH | awk '{print $4, $NF}' | sort > "$out/listeners.txt"
for u in prometheus loki alloy grafana alertmanager ntfy prometheus-node-exporter; do
  printf '%s %s\n' "$u" "$(systemd-analyze security "$u.service" --no-pager 2>/dev/null | tail -1)"
done > "$out/security.txt"
