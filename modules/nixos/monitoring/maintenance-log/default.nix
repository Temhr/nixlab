{...}: {
  # Exposed for flake/ci/monitoring-checks.nix (shellcheck); added in S39.
  flake.lib.maintenanceLoggerScript = ./maintenance-logger.sh;

  flake.nixosModules.servc--maintenance-log-nixlab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.maintenance-log-nixlab;
    checklist = import ./_internals/checklist.nix;
    checklistFile = pkgs.writeText "maintenance-checklist.tsv" (
      lib.concatMapStringsSep "\n" (s: "${s.code}\t${s.name}\t${s.hint}") checklist
    );

    # Two metric lines per section that has a cadence (last completion, 0 when never done).
    cadenceLines =
      lib.concatMapStringsSep "\n" (s: ''
        echo 'maintenance_cadence_seconds{section="${s.code}"} ${toString s.cadence}'
        v=$(awk -F'\t' -v s='${s.code}' '$1==s {print $2}' "$last")
        echo "maintenance_last_completed_timestamp_seconds{section=\"${s.code}\"} ''${v:-0}"
      '')
      (lib.filter (s: s.cadence != null) checklist);
  in {
    options.services.maintenance-log-nixlab = {
      enable = lib.mkEnableOption "maintenance task logging helper";

      logPath = lib.mkOption {
        type = lib.types.str;
        default = "/var/log/maintenance.jsonl";
        description = "Path of the maintenance log (JSON lines). Must NOT end in .log or the /var/log/*.log pipeline would ingest it twice.";
      };

      textfileDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/var/lib/node_exporter";
        description = "node_exporter textfile directory; when set, completion metrics are written there every 5 minutes.";
      };
    };

    config = lib.mkIf cfg.enable (lib.mkMerge [
      {
        assertions = [
          {
            assertion = !(lib.hasSuffix ".log" cfg.logPath);
            message = "services.maintenance-log-nixlab.logPath must not end in .log (it would also be tailed by the /var/log/*.log pipeline and ingested twice).";
          }
        ];

        # Writable by wheel only: world-writable would let any local user forge audit entries.
        systemd.tmpfiles.rules = [
          "f ${cfg.logPath} 0664 root wheel - -"
          "z ${cfg.logPath} 0664 root wheel - -"
        ];

        environment.systemPackages = [
          (pkgs.writeShellScriptBin "maintenance-log" ''
            export PATH=${lib.makeBinPath [pkgs.jq pkgs.coreutils pkgs.gawk pkgs.gnugrep]}:$PATH
            export MAINTENANCE_LOG=''${MAINTENANCE_LOG:-${lib.escapeShellArg cfg.logPath}}
            export MAINTENANCE_CHECKLIST=''${MAINTENANCE_CHECKLIST:-${checklistFile}}
            ${builtins.readFile ./maintenance-logger.sh}
          '')
          pkgs.jq
        ];

        # Monthly rotation, two years kept. copytruncate is safe because Alloy tails by position.
        services.logrotate.settings.maintenance = {
          files = [cfg.logPath];
          frequency = "monthly";
          rotate = 24;
          compress = true;
          delaycompress = true;
          copytruncate = true;
          missingok = true;
          notifempty = true;
        };
      }

      (lib.mkIf (cfg.textfileDir != null) {
        systemd.services.maintenance-log-metrics = {
          description = "Write maintenance completion metrics for node_exporter";
          path = [pkgs.jq pkgs.coreutils pkgs.gawk];
          serviceConfig.Type = "oneshot";
          script = ''
            set -eu
            out=${cfg.textfileDir}/maintenance.prom
            tmp="$out.tmp"
            last=$(mktemp)
            # Current file plus the last rotated one; bad lines are skipped by fromjson?.
            cat ${lib.escapeShellArg cfg.logPath} ${lib.escapeShellArg "${cfg.logPath}.1"} 2>/dev/null \
              | jq -rR 'fromjson? | select(.status=="completed") | [.section, (.timestamp | fromdateiso8601)] | @tsv' \
              | awk -F'\t' '{ if ($2 > m[$1]) m[$1] = $2 } END { for (s in m) print s "\t" m[s] }' > "$last"
            {
              echo '# TYPE maintenance_last_completed_timestamp_seconds gauge'
              echo '# TYPE maintenance_cadence_seconds gauge'
              ${cadenceLines}
            } > "$tmp"
            rm -f "$last"
            chmod 644 "$tmp"
            mv "$tmp" "$out"
          '';
        };

        systemd.timers.maintenance-log-metrics = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "1min";
            OnUnitActiveSec = "5min";
          };
        };
      })
    ]);
  };
}
