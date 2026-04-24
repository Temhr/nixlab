{self, ...}: {
  flake.nixosModules.hardw--c-optional--mounts-extra = {
    config,
    lib,
    pkgs,
    allHosts,
    ...
  }: {
    imports = [
      self.nixosModules.hardw--c-optional--zfs-pool-rename
    ];
    options = {
      mount-home = {
        enable = lib.mkEnableOption {
          description = "mounts home drive";
          default = false;
        };
      };
      mount-shelf = {
        enable = lib.mkEnableOption {
          description = "mounts shelf drive in home directory";
          default = false;
        };
      };
      mount-mirror = {
        enable = lib.mkEnableOption {
          description = "mounts mirror drive";
          default = false;
        };
      };
      mount-mirk1 = {
        enable = lib.mkEnableOption {
          description = "mounts mirk1 nfs";
          default = false;
        };
      };
      mount-mirk3 = {
        enable = lib.mkEnableOption {
          description = "mounts mirk3 nfs";
          default = false;
        };
      };
      mount-zfs-4dz1 = {
        enable = lib.mkEnableOption {
          description = "mounts ZFS RaidZ1 pool with 4 disks";
          default = false;
        };
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
          default = "/${config.mount-zfs-4dz1.poolName}";
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
      };
    };

    config = lib.mkMerge [
      (lib.mkIf config.mount-home.enable {
        fileSystems."/home" = {
          device = "/dev/disk/by-label/home";
          fsType = "ext4";
        };
      })
      (lib.mkIf config.mount-shelf.enable {
        fileSystems."/data" = {
          device = "/dev/disk/by-label/data";
          fsType = "ext4";
          options = ["defaults" "auto"];
        };
      })
      (lib.mkIf config.mount-mirror.enable {
        fileSystems."/mirror" = {
          device = "/dev/disk/by-label/mirror";
          fsType = "ext4";
        };
        services.nfs.server = {
          enable = true;
          exports = ''/mirror 192.168.0.0/255.255.255.0(rw,no_root_squash,fsid=0,no_subtree_check) '';
          # fixed rpc.statd port; for firewall
          lockdPort = 4001;
          mountdPort = 4002;
          statdPort = 4000;
          extraNfsdConfig = '''';
        };
        networking.firewall = {
          allowedTCPPorts = [111 2049 4000 4001 4002 20048];
          allowedUDPPorts = [111 2049 4000 4001 4002 20048];
        };
        systemd.tmpfiles.rules = ["d /mirror 1744 ${config.nixlab.mainUser} user "];
      })
      (lib.mkIf config.mount-mirk1.enable {
        fileSystems."/mnt/mirk1" = {
          device = "${allHosts.nixzen.address}:/mirror";
          fsType = "nfs";
          options = [
            "x-systemd.automount"
            "noauto"
            "_netdev"
            "x-systemd.after=network-online.target"
            "x-systemd.idle-timeout=60"
          ];
        };

        # Ensure network-online.target is actually waited for
        systemd.network.wait-online.enable = true;

        systemd.tmpfiles.rules = ["d /mnt 1744 ${config.nixlab.mainUser} user"];
      })

      (lib.mkIf config.mount-mirk3.enable {
        fileSystems."/mnt/mirk3" = {
          device = "${allHosts.nixvat.address}:/mirror";
          fsType = "nfs";
          options = [
            "x-systemd.automount"
            "noauto"
            "_netdev"
            "x-systemd.after=network-online.target"
            "x-systemd.idle-timeout=60"
          ];
        };

        systemd.network.wait-online.enable = true;

        systemd.tmpfiles.rules = ["d /mnt 1744 ${config.nixlab.mainUser} user"];
      })

      (lib.mkIf config.mount-zfs-4dz1.enable (let
        cfg        = config.mount-zfs-4dz1;
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
              ZED_NOTIFY_DATA = true;  # Data errors
              ZED_NOTIFY_IO_ERRORS = true;  # I/O errors
              ZED_NOTIFY_RESILVER = true;  # Resilver (rebuild) events

              # Send email on these events
              ZED_EMAIL_INTERVAL_SECS = 3600;  # Minimum 1 hour between emails
            };
          };
        };

        # Import the pool by its desired name (rename service ensures this name is correct)
        boot.zfs.extraPools = [cfg.poolName];

        # Mount the pool root dataset at the configured mountpoint.
        # Must wait for the rename service so the import sees the correct name.
        fileSystems."${mountPoint}" = {
          device  = cfg.poolName;
          fsType  = "zfs";
          options = ["x-systemd.after=zfs-pool-rename.service"];
        };

        # Create mount point directory
        systemd.tmpfiles.rules = [
          "d ${mountPoint} 1755 ${config.nixlab.mainUser} user"
        ];

        # Delegate pool rename to the dedicated module, passing poolName + devices
        # as the fingerprint. The module is a no-op if the pool is already correctly named.
        zfs-pool-rename = {
          enable     = true;
          poolName   = cfg.poolName;
          mountPoint = cfg.mountPoint;
          devices    = cfg.devices;
        };

        # ZFS health monitoring service
        systemd.services.zfs-health-check = lib.mkIf cfg.enableMonitoring {
          description = "ZFS Pool Health Check";
          path = [ config.boot.zfs.package ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = toString (pkgs.writeShellScript "zfs-health-check" ''
              POOL="${cfg.poolName}"

              # Check pool status
              STATUS=$(zpool status -x "$POOL")

              if [ "$STATUS" != "all pools are healthy" ]; then
                echo "WARNING: ZFS pool $POOL is not healthy!"
                echo "$STATUS"

                # Log to journal
                logger -t zfs-health-check "ZFS pool $POOL health issue detected"

                ${lib.optionalString (cfg.alertEmail != "") ''
                  # Send email alert if configured
                  echo "$STATUS" | mail -s "ZFS Pool Alert: $POOL degraded" ${cfg.alertEmail}
                ''}

                exit 1
              fi

              echo "ZFS pool $POOL is healthy"
              exit 0
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

        # IMPORTANT: You must also set networking.hostId in your main configuration!
        # Generate one with: head -c 8 /etc/machine-id
        # Then add to your config: networking.hostId = "a1b2c3d4";

        # Note: The pool must be created manually before enabling this option:
        # sudo zpool create -f ${cfg.poolName} raidz1 \
        #   ${lib.concatStringsSep " " cfg.devices}
        # It will be mounted at ${mountPoint}
        # To rename: just change poolName — the rename service will detect the
        # old name automatically on next boot and rename it in place.
      }))
    ];
  };
}
