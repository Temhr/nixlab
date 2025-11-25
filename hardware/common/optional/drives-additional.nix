{ config, lib, pkgs, ... }: {

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
  };

  config = lib.mkMerge [
    (lib.mkIf config.mount-home.enable {
        fileSystems."/home" =
            { device = "/dev/disk/by-label/home";
              fsType = "ext4";
            };
    })
    (lib.mkIf config.mount-shelf.enable {
        fileSystems."/home/temhr/shelf" =
            { device = "/dev/disk/by-label/shelf";
              fsType = "ext4";
              options = [ "defaults" "auto" ];
            };
        /*
        systemd.services.fix-shelf-permissions = {
          description = "Fix ownership of /home/temhr/shelf for temhr user";
          wantedBy = [ "local-fs.target" ];
          after = [ "local-fs.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "/run/current-system/sw/bin/chown -R temhr:users /home/temhr/shelf";
          };
        };
        */
    })
    (lib.mkIf config.mount-mirror.enable {
        fileSystems."/mirror" =
            { device = "/dev/disk/by-label/mirror";
            fsType = "ext4";
            };
        services.nfs.server = {
            enable = true;
            exports = '' /mirror 192.168.0.0/255.255.255.0(rw,no_root_squash,fsid=0,no_subtree_check) '';
            # fixed rpc.statd port; for firewall
            lockdPort = 4001;
            mountdPort = 4002;
            statdPort = 4000;
            extraNfsdConfig = '''';
        };
        networking.firewall = {
            allowedTCPPorts = [ 111 2049 4000 4001 4002 20048 ];
            allowedUDPPorts = [ 111 2049 4000 4001 4002 20048 ];
        };
        systemd.tmpfiles.rules = [ "d /mirror 1744 temhr user " ];
    })
    (lib.mkIf config.mount-mirk1.enable {
      fileSystems."/mnt/mirk1" = {
        device = "192.168.0.204:/mirror";
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

      systemd.tmpfiles.rules = [ "d /mnt 1744 temhr user" ];
    })

    (lib.mkIf config.mount-mirk3.enable {
      fileSystems."/mnt/mirk3" = {
        device = "192.168.0.201:/mirror";
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

      systemd.tmpfiles.rules = [ "d /mnt 1744 temhr user" ];
    })
  ];
}
