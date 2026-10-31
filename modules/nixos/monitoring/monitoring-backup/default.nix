{...}: {
  flake.nixosModules.servc--monitoring-backup-nixlab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.monitoring-backup-nixlab;
  in {
    options.services.monitoring-backup-nixlab = {
      enable = lib.mkEnableOption "consistent copies of the monitoring stack's state";

      dir = lib.mkOption {
        type = lib.types.str;
        example = "/data/backup";
        description = "Directory the copies are written to. Include it in your normal backup (backup-home sources).";
      };

      sqliteFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "SQLite databases, copied with sqlite3 .backup.";
      };

      plainFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Files or directories copied as they are.";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.services.monitoring-backup = {
        description = "Copy monitoring state for backup";
        path = [pkgs.sqlite pkgs.coreutils];
        serviceConfig = {
          Type = "oneshot";
          UMask = "0077";
        };
        script = ''
          set -eu
          mkdir -p ${cfg.dir}
          ${lib.concatMapStringsSep "\n" (f: ''
              if [ -f ${f} ]; then sqlite3 ${f} ".backup '${cfg.dir}/$(basename ${f}).bak'"; fi
            '')
            cfg.sqliteFiles}
          ${lib.concatMapStringsSep "\n" (f: ''
              if [ -e ${f} ]; then cp -a ${f} ${cfg.dir}/; fi
            '')
            cfg.plainFiles}
        '';
      };

      systemd.timers.monitoring-backup = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "03:15";
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
      };
    };
  };
}
