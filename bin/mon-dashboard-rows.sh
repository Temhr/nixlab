#!/usr/bin/env bash
# S49: add the SMART, timer, logs and maintenance rows; mark the health gauge. Idempotent.
set -euo pipefail
D=${1:-modules/nixos/monitoring/grafana/dashboards}
F="$D/system-overview-v5.json"

jq '
  def ds: {type: "prometheus", uid: "${DS_PROMETHEUS}"};
  def lds: {type: "loki", uid: "loki"};
  def row($t; $y): {type: "row", title: $t, collapsed: false, gridPos: {h: 1, w: 24, x: 0, y: $y}};
  def ts($id; $t; $x; $y; $w; $unit; $expr; $legend; $d): {
    id: $id, type: "timeseries", title: $t, datasource: $d, gridPos: {h: 8, w: $w, x: $x, y: $y},
    targets: [{refId: "A", expr: $expr, legendFormat: $legend, datasource: $d}],
    fieldConfig: {defaults: {unit: $unit, custom: {fillOpacity: 10}}}};
  def bar($id; $t; $x; $y; $w; $unit; $expr; $legend; $steps): {
    id: $id, type: "bargauge", title: $t, datasource: ds, gridPos: {h: 8, w: $w, x: $x, y: $y},
    targets: [{refId: "A", expr: $expr, legendFormat: $legend, instant: true, datasource: ds}],
    fieldConfig: {defaults: {unit: $unit, min: 0, noValue: "no data", thresholds: {mode: "absolute", steps: $steps}}},
    options: {orientation: "horizontal", displayMode: "gradient", showUnfilled: true, reduceOptions: {calcs: ["lastNotNull"], values: false}}};
  def logs($id; $t; $x; $y; $w; $expr; $from): {
    id: $id, type: "logs", title: $t, datasource: lds, gridPos: {h: 8, w: $w, x: $x, y: $y},
    targets: [{refId: "A", expr: $expr, datasource: lds}],
    options: {showTime: true, wrapLogMessage: true, sortOrder: "Descending"}} + (if $from == null then {} else {timeFrom: $from} end);

  (.panels | map(.gridPos.y + .gridPos.h) | max) as $b

  | if any(.panels[]; .id == 400) then .
    else .panels += [
      row("💽 Drive health"; $b),
      bar(400; "SMART status (1 = healthy)"; 0; $b + 1; 8; "short"; "smartctl_device_smart_status"; "{{instance}} {{device}}";
          [{color: "red", value: null}, {color: "green", value: 1}]),
      ts(401; "Drive temperature"; 8; $b + 1; 8; "celsius"; "smartctl_device_temperature"; "{{instance}} {{device}}"; ds),
      ts(402; "NVMe wear (percent of endurance used)"; 16; $b + 1; 8; "percent"; "smartctl_device_percentage_used"; "{{instance}} {{device}}"; ds),

      row("🔧 Timers"; $b + 9),
      bar(412; "Time since each timer last fired"; 0; $b + 10; 24; "s";
          "time() - node_systemd_timer_last_trigger_seconds{name=~\"nixos-upgrade.timer|flake-update.timer|backup-home.timer|nixlab-gpull.timer|nix-gc.timer\"}";
          "{{instance}} {{name}}"; [{color: "green", value: null}, {color: "yellow", value: 172800}, {color: "red", value: 345600}]),

      row("📜 Logs"; $b + 18),
      ts(420; "Journal errors by unit"; 0; $b + 19; 12; "short";
         "sum by (unit) (count_over_time({job=\"systemd-journal\", level=~\"err|crit|alert|emerg\"}[$__interval]))"; "{{unit}}"; lds),
      ts(421; "Failed SSH logins"; 12; $b + 19; 12; "short";
         "sum by (host) (count_over_time({job=\"systemd-journal\", unit=\"sshd.service\"} |~ \"Failed password|Invalid user\" [$__interval]))"; "{{host}}"; lds),
      logs(422; "Kernel warnings"; 0; $b + 27; 24; "{job=\"systemd-journal\", transport=\"kernel\"} |~ \"(?i)error|fail|warn\""; null),

      row("📝 Maintenance"; $b + 35),
      bar(430; "Days since last completed (cadence sections)"; 0; $b + 36; 12; "d";
          "(time() - maintenance_last_completed_timestamp_seconds) / 86400"; "{{instance}} {{section}}";
          [{color: "green", value: null}, {color: "yellow", value: 30}, {color: "red", value: 90}]),
      logs(431; "Failed or skipped in the last 90 days"; 12; $b + 36; 12; "{job=\"maintenance-log\", status=~\"failed|skipped\"}"; "90d"),
      logs(432; "Recent maintenance entries"; 0; $b + 44; 24; "{job=\"maintenance-log\"}"; null)
    ] end

  # The health gauge must say so when the stack is down instead of reading as healthy.
  | (.panels[] | select(.id == 1) | .fieldConfig.defaults.noValue) = "NO DATA"
' "$F" > "$F.tmp" && mv "$F.tmp" "$F"

echo "rows applied"
