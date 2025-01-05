
{ config, lib, pkgs, modulesPath, ... }:

{
  fileSystems."/home" =
    { device = "/dev/disk/by-label/home";
      fsType = "ext4";
    };

  fileSystems."/home/temhr/shelf" =
    { device = "/dev/disk/by-label/shelf";
      fsType = "ext4";
    };

  fileSystems."/mnt/mirser" =
    { device = "192.168.0.203:/mirror";
      fsType = "nfs";
      options = [
        "x-systemd.automount" "noauto"
        "x-systemd.idle-timeout=60" # disconnects after 60 seconds
      ];
    };

  systemd.tmpfiles.rules = [
    "d /home/temhr/shelf 1777 root root "
    "d /mnt 1770 root root "
  ];

}
