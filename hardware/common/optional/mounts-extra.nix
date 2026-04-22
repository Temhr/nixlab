{...}: {
  flake.nixosModules.hardw--c-optional--mounts-extra = {
    config,
    lib,
    allHosts,
    ...
  }: {
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
          description = "Name of the ZFS pool";
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
        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/zpool";
          description = "Mount point for the ZFS pool";
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

      (lib.mkIf config.mount-zfs-4dz1.enable {
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
            enableMail = config.mount-zfs-4dz1.enableMonitoring && (config.mount-zfs-4dz1.alertEmail != "");
            settings = lib.mkIf config.mount-zfs-4dz1.enableMonitoring {
              ZED_EMAIL_ADDR = lib.mkIf (config.mount-zfs-4dz1.alertEmail != "") config.mount-zfs-4dz1.alertEmail;
              ZED_EMAIL_PROG = "${lib.getExe' config.boot.kernelPackages.zfs "zed"}";
              ZED_EMAIL_OPTS = "@ADDRESS@";

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

        # Import the pool
        boot.zfs.extraPools = [config.mount-zfs-4dz1.poolName];

        # Mount the pool
        fileSystems."${config.mount-zfs-4dz1.mountPoint}" = {
          device = config.mount-zfs-4dz1.poolName;
          fsType = "zfs";
        };

        # Create mount point directory
        systemd.tmpfiles.rules = [
          "d ${config.mount-zfs-4dz1.mountPoint} 1755 ${config.nixlab.mainUser} user"
        ];

        # ZFS health monitoring service
        systemd.services.zfs-health-check = lib.mkIf config.mount-zfs-4dz1.enableMonitoring {
          description = "ZFS Pool Health Check";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = let
              healthCheckScript = lib.getExe (config.boot.kernelPackages.zfs.overrideAttrs (old: {
                name = "zfs-health-check";
                buildCommand = ''
                  mkdir -p $out/bin
                  cat > $out/bin/zfs-health-check <<'EOF'
                  #!/bin/sh
                  POOL="${config.mount-zfs-4dz1.poolName}"

                  # Check pool status
                  STATUS=$(zpool status -x "$POOL")

                  if [ "$STATUS" != "all pools are healthy" ]; then
                    echo "WARNING: ZFS pool $POOL is not healthy!"
                    echo "$STATUS"

                    # Log to journal
                    logger -t zfs-health-check "ZFS pool $POOL health issue detected"

                    ${lib.optionalString (config.mount-zfs-4dz1.alertEmail != "") ''
                      # Send email alert if configured
                      echo "$STATUS" | mail -s "ZFS Pool Alert: $POOL degraded" ${config.mount-zfs-4dz1.alertEmail}
                    ''}

                    exit 1
                  fi

                  echo "ZFS pool $POOL is healthy"
                  exit 0
                  EOF
                  chmod +x $out/bin/zfs-health-check
                '';
              }));
            in "${healthCheckScript}/bin/zfs-health-check";
          };
        };

        # Run health check daily
        systemd.timers.zfs-health-check = lib.mkIf config.mount-zfs-4dz1.enableMonitoring {
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
        # sudo zpool create -f ${config.mount-zfs-4dz1.poolName} raidz1 \
        #   ${lib.concatStringsSep " " config.mount-zfs-4dz1.devices}
      })
    ];
  };
}
