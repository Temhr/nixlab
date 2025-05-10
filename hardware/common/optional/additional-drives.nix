{ config, lib, ... }: {

  options = {
      mount-home = {
          enable = lib.mkEnableOption "mounts home drive";
      };
      mount-mirror = {
          enable = lib.mkEnableOption "mounts mirror drive";
      };
      mount-mirk1 = {
          enable = lib.mkEnableOption "mounts mirk1 nfs";
      };
      mount-mirk3 = {
          enable = lib.mkEnableOption "mounts mirk3 nfs";
      };
  };

  config = lib.mkMerge [
    (lib.mkIf config.mount-home.enable {
        fileSystems."/home" =
            { device = "/dev/disk/by-label/home";
              fsType = "ext4";
            };
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
    })
    (lib.mkIf config.mount-mirk1.enable {
        fileSystems."/mnt/mirk1" =
            { device = "192.168.0.201:/mirror";
              fsType = "nfs";
              options = [
                "x-systemd.automount" "noauto"
                "x-systemd.after=network-online.target"
                "x-systemd.idle-timeout=60" # disconnects after 60 seconds
              ];
            };
        systemd.tmpfiles.rules = [ "d /mnt 1744 temhr user " ];
    })
    (lib.mkIf config.mount-mirk3.enable {
        fileSystems."/mnt/mirk3" =
            { device = "192.168.0.204:/mirror";
              fsType = "nfs";
              options = [
                "x-systemd.automount" "noauto"
                "x-systemd.after=network-online.target"
                "x-systemd.idle-timeout=60" # disconnects after 60 seconds
              ];
            };
        systemd.tmpfiles.rules = [ "d /mnt 1744 temhr user " ];
    })
  ];
}
