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
      mount-4dz1 = {
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

      (lib.mkIf config.mount-4dz1.enable {
        # Enable ZFS support
        boot.supportedFilesystems = ["zfs"];
        boot.zfs.forceImportRoot = false;

        # ZFS services
        services.zfs = {
          autoScrub.enable = true;
          autoScrub.interval = "weekly";
          trim.enable = true;
        };

        # Import the pool
        boot.zfs.extraPools = [config.mount-4dz1.poolName];

        # Mount the pool
        fileSystems."${config.mount-4dz1.mountPoint}" = {
          device = config.mount-4dz1.poolName;
          fsType = "zfs";
        };

        # Create mount point directory
        systemd.tmpfiles.rules = [
          "d ${config.mount-4dz1.mountPoint} 1755 ${config.nixlab.mainUser} user"
        ];

        # Note: The pool must be created manually before enabling this option:
        # sudo zpool create -f ${config.mount-4dz1.poolName} raidz1 \
        #   ${lib.concatStringsSep " " config.mount-4dz1.devices}
      })
    ];
  };
}
