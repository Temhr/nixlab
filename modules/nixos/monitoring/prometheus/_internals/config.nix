# ============================================================================
# FILE: prometheus/config.nix
# ============================================================================
{
  config,
  lib,
  pkgs,
  nixlabLib,
  ...
}: let
  cfg = config.services.prometheus-nixlab;

  # Import specialized configurations
  prometheusService = import ./services/prometheus.nix {inherit config lib pkgs nixlabLib;};
  nodeExporterService = import ./exporters/node.nix {inherit config lib pkgs nixlabLib;};
  maintenanceExporters = import ./exporters/maintenance.nix {inherit config lib pkgs;};
  nginxConfig = import ./extras/nginx.nix {inherit config lib nixlabLib;};
in {
  # Directory setup
  systemd.tmpfiles.rules =
    [
      "d ${cfg.dataDir} 0770 prometheus prometheus -"
    ]
    ++ lib.optionals cfg.maintenance.enable [
      "d /var/lib/node_exporter 0755 prometheus prometheus -"
    ];

  # User configuration
  users.users = lib.mkMerge (
    [
      {
        prometheus = {
          isSystemUser = true;
          group = "prometheus";
          home = cfg.dataDir;
          description = "Prometheus service user";
          extraGroups =
            lib.optional
            (cfg.maintenance.enable && cfg.maintenance.exporters.smartctl.enable)
            "disk";
        };
      }
    ]
    ++ lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
    (map (u: {${u} = {extraGroups = ["prometheus"];};})
      ([config.nixlab.mainUser] ++ cfg.extraUsers))
  );

  users.groups.prometheus = {};

  # ----------------------------------------------------------------------------
  # SERVICES - main unit, node exporter, maintenance exporters, and the
  # PERMISSIONS oneshot that fixes dataDir ownership every boot, after
  # dataDir is actually mounted.
  #
  # This module hardcodes the "prometheus" user/group rather than exposing
  # cfg.user/cfg.group options, so prometheus-permissions does the same —
  # fixes both the tmpfiles-vs-separate-mount race and any UID/GID drift on
  # cfg.dataDir across a rebuild. Does not cover /var/lib/node_exporter: that
  # directory is managed by systemd's own StateDirectory= mechanism on the
  # node-exporter unit, which already re-asserts ownership at every start.
  #
  # All merged into one assignment: this file returns a plain attrset, not
  # something passed through lib.mkMerge, so systemd.services can only be
  # assigned once here or Nix sees two definitions of the same attribute
  # path and throws.
  # ----------------------------------------------------------------------------
  systemd.services =
    {
      prometheus-permissions = nixlabLib.mkDataDirPermissionsService {
        inherit pkgs;
        dataDir = cfg.dataDir;
        user = "prometheus";
        group = "prometheus";
        requiredBy = ["prometheus.service"];
      };
      prometheus = prometheusService;
      prometheus-node-exporter = lib.mkIf cfg.enableNodeExporter nodeExporterService;

      # Quarantine the head and WAL when Prometheus is up but its TSDB time is wrong.
      prometheus-tsdb-guard = {
        description = "Quarantine Prometheus head/WAL when its TSDB time is wrong";
        path = [pkgs.curl pkgs.jq pkgs.coreutils pkgs.gnugrep pkgs.systemd];
        serviceConfig = {
          Type = "oneshot";
          StateDirectory = "prometheus-tsdb-guard";
        };
        script = ''
          set -eu
          stamp=/var/lib/prometheus-tsdb-guard/last
          now=$(date +%s)
          # 6 hour cooldown, so a persistent fault cannot loop and eat data.
          if [ -f "$stamp" ] && [ $((now - $(cat "$stamp"))) -lt 21600 ]; then exit 0; fi
          # If Prometheus is down, other alerts cover that. This guard only handles "up but wrong".
          max=$(curl -sf http://127.0.0.1:${toString cfg.port}/api/v1/status/tsdb \
            | jq -r '.data.headStats.maxTime / 1000 | floor') || exit 0
          oob=$(journalctl -u prometheus --since -15min -o cat --no-pager \
            | grep -ciE 'out of bounds|too far into the future' || true)
          if [ $((max - now)) -gt 3600 ] || [ "$oob" -gt 100 ]; then
            ts=$(date +%Y%m%d-%H%M%S)
            systemctl stop prometheus
            mv ${cfg.dataDir}/data/wal ${cfg.dataDir}/data/wal.broken-$ts
            mv ${cfg.dataDir}/data/chunks_head ${cfg.dataDir}/data/chunks_head.broken-$ts 2>/dev/null || true
            echo "$now" > "$stamp"
            systemctl start prometheus
          fi
        '';
      };
    }
    // maintenanceExporters.services;

  systemd.timers.prometheus-tsdb-guard = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "15min";
      OnUnitActiveSec = "5min";
    };
  };

  # Import exporter configurations
  services.prometheus.exporters = maintenanceExporters.exporters;

  # Nginx configuration
  services.nginx = nginxConfig;

  # Firewall configuration
  networking.firewall.allowedTCPPorts =
    lib.mkIf cfg.openFirewall
    (nixlabLib.mkFirewallPorts {
      inherit (cfg) domain listenAddress;
      servicePort = cfg.port;
    });
}
