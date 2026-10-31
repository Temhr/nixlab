#!/usr/bin/env bash
# S47: normalise the Grafana dashboard JSON files. Idempotent.
set -euo pipefail
D=${1:-modules/nixos/monitoring/grafana/dashboards}
fix() { local f=$1; shift; jq "$@" "$f" > "$f.tmp" && mv "$f.tmp" "$f"; }

for f in "$D"/*.json; do
  # The first threshold step is the base colour and must have value null.
  fix "$f" '(.. | select(type=="object" and has("steps")) | .steps[0].value) = null'
  # "days" is not a Grafana unit; "d" is.
  fix "$f" '(.. | select(type=="object" and .unit? == "days") | .unit) = "d"'
done

C="$D/maintenance-checklist.json"
# Identity and schema version, so Grafana does not re-migrate from schema 0 and the provisioning cleanup can match the uid.
fix "$C" '. + {id: null, uid: "maintenance-checklist", schemaVersion: 36}'
# Legacy value mappings -> the current format used by system-overview-v5.
fix "$C" '(.. | select(type=="object" and .id? == "mappings" and (.value | type == "array") and ((.value[0]? | type) == "object") and (.value[0] | has("text"))) | .value)
          |= [{type: "value", options: (map({(.value): {text: .text, color: .color}}) | add)}]'
# An empty count() returns no series; add a zero so the stat shows 0 instead of "No data".
fix "$C" '(.panels[] | select(.id == 2) | .targets[] | .expr) |= (if endswith(" or vector(0)") then . else . + " or vector(0)" end)'
echo "dashboards normalised in $D"
