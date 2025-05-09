
{ config, lib, pkgs, modulesPath, ... }:

{
#  fileSystems."/home/temhr/shelf" =
#    { device = "/dev/disk/by-label/shelf";
#      fsType = "ext4";
#    };
  fileSystems."/mnt/mirbase" =
    { device = "192.168.0.201:/mirror";
      fsType = "nfs";
      options = [
        "x-systemd.automount" "noauto"
        "x-systemd.after=network-online.target"
        "x-systemd.idle-timeout=60" # disconnects after 60 seconds
      ];
    };
  fileSystems."/mnt/mirzer" =
    { device = "192.168.0.204:/mirror";
      fsType = "nfs";
      options = [
        "x-systemd.automount" "noauto"
        "x-systemd.after=network-online.target"
        "x-systemd.idle-timeout=60" # disconnects after 60 seconds
      ];
    };

  systemd.tmpfiles.rules = [
#   "d /home/temhr/shelf 1744 temhr users "
    "d /mnt 1744 temhr users "
  ];
}
