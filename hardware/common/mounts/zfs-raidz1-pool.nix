{self, ...}: {
  flake.nixosModules.hardw--mounts--zfs-raidz1-pool = {
    config,
    lib,
    pkgs,
    ...
  }: {
    imports = [
      self.nixosModules.hardw--mounts--zfs-pool-rename
    ];
    options = {
      zfsRaidz1Pool = {
        enable = lib.mkEnableOption "mounts ZFS RaidZ1 pool with 4 disks";

        poolName = lib.mkOption {
          type = lib.types.str;
          default = "tank";
          description = ''
            Desired name of the ZFS pool. On each boot, if no pool with this
            name is found but exactly one other importable pool exists, it will
            be automatically renamed to this name.
          '';
        };
        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/${config.zfsRaidz1Pool.poolName}";
          description = "Filesystem path to mount the ZFS pool root dataset. Defaults to /<poolName>.";
        };
        devices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "/dev/disk/by-id/disk1"
            "/dev/disk/by-id/disk2"
            "/dev/disk/by-id/disk3"
            "/dev/disk/by-id/disk4"
          ];
          description = "List of 4 disk devices for RaidZ1";
        };
        enableMonitoring = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable ZFS health monitoring and email alerts";
        };
        alertEmail = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Email address for ZFS health alerts (requires mail to be configured)";
        };
        nfs = {
          enable = lib.mkEnableOption "NFS server to export the ZFS pool";
          exportPath = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Path to export via NFS. Leave empty to use the ZFS mount point.";
          };
          allowedNetwork = lib.mkOption {
            type = lib.types.str;
            default = "10.0.0.0/255.255.255.0";
            description = "Network CIDR to allow NFS access (e.g., 10.0.0.0/255.255.255.0)";
          };
          exportOptions = lib.mkOption {
            type = lib.types.str;
            default = "rw,no_root_squash,fsid=0,no_subtree_check";
            description = "NFS export options";
          };
        };
      };
    };

    config = lib.mkMerge [
      (lib.mkIf config.zfsRaidz1Pool.enable (let
        cfg = config.zfsRaidz1Pool;
        mountPoint = cfg.mountPoint;
      in {
        # Enable ZFS support
        boot.supportedFilesystems = ["zfs"];
        boot.zfs.forceImportRoot = false;

        # ZFS services
        services.zfs = {
          autoScrub.enable = true;
          autoScrub.interval = "weekly";
          trim.enable = true;

          # Enable ZFS Event Daemon for monitoring and alerts
          zed = {
            enableMail = cfg.enableMonitoring && (cfg.alertEmail != "");
            settings = lib.mkIf cfg.enableMonitoring {
              ZED_EMAIL_ADDR = lib.mkIf (cfg.alertEmail != "") cfg.alertEmail;
              ZED_EMAIL_PROG = "mail";
              ZED_EMAIL_OPTS = "-s '@SUBJECT@' @ADDRESS@";

              # Alert on pool state changes
              ZED_NOTIFY_VERBOSE = true;

              # Specific events to monitor
              ZED_NOTIFY_DATA = true; # Data errors
              ZED_NOTIFY_IO_ERRORS = true; # I/O errors
              ZED_NOTIFY_RESILVER = true; # Resilver (rebuild) events

              # Send email on these events
              ZED_EMAIL_INTERVAL_SECS = 3600; # Minimum 1 hour between emails
            };
          };
        };

        # Import the pool by its desired name (rename service ensures this name is correct)
        boot.zfs.extraPools = [cfg.poolName];

        # Mount the pool root dataset at the configured mountpoint.
        # Must wait for the rename service so the import sees the correct name.
        fileSystems."${mountPoint}" = {
          device = cfg.poolName;
          fsType = "zfs";
          options = ["x-systemd.after=zfs-pool-rename.service"];
        };

        # Create mount point directory
        systemd.tmpfiles.rules = [
          "d ${mountPoint} 0775 ${config.nixlab.mainUser} users"
        ];

        # Delegate pool rename to the dedicated module, passing poolName + devices
        # as the fingerprint. The module is a no-op if the pool is already correctly named.
        zfs-pool-rename = {
          enable = true;
          poolName = cfg.poolName;
          mountPoint = cfg.mountPoint;
          devices = cfg.devices;
        };

        # ZFS health monitoring service
        systemd.services.zfs-integrity-metrics = lib.mkIf cfg.enableMonitoring {
          description = "Export ZFS error counters and scrub history";
          path = [config.boot.zfs.package pkgs.jq pkgs.coreutils];
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "zfs-integrity-metrics";
          };
          script = ''
            pool="${cfg.poolName}"
            dir=/var/lib/node_exporter
            state=/var/lib/zfs-integrity-metrics
            now=$(date +%s)

            json=$(zpool status -j --json-int "$pool")

            # scan_stats only describes the latest scan (a resilver overwrites a scrub),
            # so remember the last scrub that finished.
            fn=$(jq -r --arg p "$pool" '.pools[$p].scan_stats.function // ""' <<<"$json")
            st=$(jq -r --arg p "$pool" '.pools[$p].scan_stats.state // ""' <<<"$json")
            if [ "$fn" = SCRUB ] && [ "$st" = FINISHED ]; then
              jq -r --arg p "$pool" '.pools[$p].scan_stats | "\(.end_time) \(.errors)"' <<<"$json" > "$state/last-scrub"
            fi
            # No scrub known yet: start the "overdue" clock at first run.
            [ -s "$state/last-scrub" ] || echo "$now 0" > "$state/last-scrub"
            read -r scrub_end scrub_errors < "$state/last-scrub"

            tmp=$(mktemp -p "$dir" .zfs_integrity.XXXXXX)
            {
              echo '# TYPE zfs_vdev_errors gauge'
              jq -r --arg p "$pool" '
                .pools[$p].vdevs | .. | objects | select(has("vdev_type"))
                | . as $v
                | ("read_errors","write_errors","checksum_errors") as $k
                | "zfs_vdev_errors{pool=\"\($p)\",device=\"\($v.name)\",vdev_type=\"\($v.vdev_type)\",type=\"\($k | sub("_errors";""))\"} \($v[$k] // 0)"
              ' <<<"$json"
              echo '# TYPE zfs_pool_error_count gauge'
              echo "zfs_pool_error_count{pool=\"$pool\"} $(jq -r --arg p "$pool" '.pools[$p].error_count // 0' <<<"$json")"
              echo '# TYPE zfs_last_scrub_end_timestamp_seconds gauge'
              echo "zfs_last_scrub_end_timestamp_seconds{pool=\"$pool\"} $scrub_end"
              echo '# TYPE zfs_last_scrub_errors gauge'
              echo "zfs_last_scrub_errors{pool=\"$pool\"} $scrub_errors"
            } > "$tmp"
            chmod 644 "$tmp"
            mv "$tmp" "$dir/zfs_integrity.prom"
          '';
        };

        systemd.timers.zfs-integrity-metrics = lib.mkIf cfg.enableMonitoring {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = "1min";
          };
        };

        systemd.services.zfs-member-reconcile = lib.mkIf cfg.enableMonitoring {
          description = "Export ZFS member-disk status and re-online returned disks";
          path = [config.boot.zfs.package pkgs.coreutils pkgs.gawk pkgs.util-linux];
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "zfs-member-reconcile";
          };
          script = ''
            pool="${cfg.poolName}"
            dir=/var/lib/node_exporter
            stamps=/var/lib/zfs-member-reconcile
            now=$(date +%s)
            status=$(zpool status "$pool" 2>/dev/null || true)
            tmp=$(mktemp -p "$dir" .zfs_devices.XXXXXX)
            : > "$tmp"

            ${lib.concatMapStringsSep "\n" (d: let
                n = baseNameOf d;
              in ''
                if [ -e "${d}" ]; then present=1; else present=0; fi
                state=$(printf '%s\n' "$status" | awk -v n="${n}" '$1 == n { print $2; exit }')
                [ -n "$state" ] || state=UNKNOWN
                last=0
                [ -f "$stamps/${n}" ] && last=$(cat "$stamps/${n}")

                # Disk is back at the OS level but ZFS still has it REMOVED/UNAVAIL: online it (5 min cooldown)
                if [ "$present" = 1 ] && { [ "$state" = REMOVED ] || [ "$state" = UNAVAIL ]; } && [ $((now - last)) -ge 300 ]; then
                  logger -t zfs-member-reconcile "${n} is present but ZFS reports $state; running zpool online"
                  zpool online "$pool" "${n}" || logger -t zfs-member-reconcile "zpool online ${n} failed"
                  echo "$now" > "$stamps/${n}"
                  last=$now
                fi

                online=0
                [ "$state" = ONLINE ] && online=1
                printf 'zfs_expected_device_present{pool="%s",device="%s"} %s\n' "$pool" "${n}" "$present" >> "$tmp"
                printf 'zfs_expected_device_online{pool="%s",device="%s"} %s\n' "$pool" "${n}" "$online" >> "$tmp"
                printf 'zfs_device_last_auto_online_timestamp_seconds{pool="%s",device="%s"} %s\n' "$pool" "${n}" "$last" >> "$tmp"
              '')
              cfg.devices}

            chmod 644 "$tmp"
            mv "$tmp" "$dir/zfs_devices.prom"
          '';
        };

        systemd.timers.zfs-member-reconcile = lib.mkIf cfg.enableMonitoring {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "1min";
            OnUnitActiveSec = "30s";
          };
        };

        systemd.services.zfs-health-check = lib.mkIf cfg.enableMonitoring {
          description = "ZFS Pool Health Check";
          path =
            [config.boot.zfs.package pkgs.util-linux]
            ++ lib.optional (cfg.alertEmail != "") pkgs.mailutils;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = toString (pkgs.writeShellScript "zfs-health-check" ''
              POOL="${cfg.poolName}"

              # Check pool status
              HEALTH=$(zpool list -H -o health "$POOL" 2>&1)

              if [ "$HEALTH" != "ONLINE" ]; then
                echo "WARNING: ZFS pool $POOL health is: $HEALTH"
                zpool status "$POOL"
                logger -t zfs-health-check "ZFS pool $POOL health: $HEALTH"
                ${lib.optionalString (cfg.alertEmail != "") ''
                # Send email alert if configured
                zpool status "$POOL" | mail -s "ZFS Pool Alert: $POOL $HEALTH" ${cfg.alertEmail}
              ''}
                exit 1
              fi

              echo "ZFS pool $POOL is healthy"
            '');
          };
        };

        # Run health check daily
        systemd.timers.zfs-health-check = lib.mkIf cfg.enableMonitoring {
          description = "Daily ZFS Pool Health Check";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            Unit = "zfs-health-check.service";
          };
        };

        # NFS server configuration
        nfsMirrorServer = lib.mkIf cfg.nfs.enable {
          enable = true;
          exportPath =
            if cfg.nfs.exportPath != ""
            then cfg.nfs.exportPath
            else cfg.mountPoint;
          allowedNetwork = cfg.nfs.allowedNetwork;
          exportOptions = cfg.nfs.exportOptions;
        };

        # IMPORTANT: You must also set networking.hostId in your main configuration!
        # Generate one with: head -c 8 /etc/machine-id
        # Then add to your config: networking.hostId = "a1b2c3d4";

        # Note: The pool must be created manually before enabling this option:
        # sudo zpool create -f ${cfg.poolName} raidz1 \
        #   ${lib.concatStringsSep " " cfg.devices}
        # It will be mounted at ${mountPoint}
        # To rename: just change poolName — the rename service will detect the
        # old name automatically on next boot and rename it in place.
        #
        # To enable NFS export, set zfsRaidz1Pool.nfs.enable = true;
        # This will export ${mountPoint} to the configured network with NFS.
      }))
    ];
  };
}
