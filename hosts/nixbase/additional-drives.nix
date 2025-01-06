
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
  fileSystems."/mirror" =
    { device = "/dev/disk/by-uuid/a777497d-228b-47a2-bd3c-71f8eb8d1315";
      fsType = "ext4";
    };
  fileSystems."/mnt/mirser" =
    { device = "192.168.0.203:/mirror";
      fsType = "nfs";
      options = [
        "x-systemd.automount" "noauto"
        "x-systemd.after=network-online.target"
        "x-systemd.idle-timeout=60" # disconnects after 60 seconds
      ];
    };

  systemd.tmpfiles.rules = [
    "d /home/temhr/shelf 1777 root root "
    "d /mirror 1770 root root "
    "d /mnt 1770 root root "
  ];

  services.nfs.server.enable = true;
  services.nfs.server.exports = '' /mirror 192.168.0.0/255.255.255.0(rw,no_root_squash,fsid=0,no_subtree_check) '';
  networking.firewall.enable = false;
}
