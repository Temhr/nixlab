
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

  fileSystems."/run/media/temhr/HGST" =
    { device = "/dev/disk/by-label/HGST";
      fsType = "ext4";
    };
  systemd.tmpfiles.rules = [
    "d /home/temhr/shelf 1777 root root "
    "d /run/media/temhr 1770 root root "
  ];
}
