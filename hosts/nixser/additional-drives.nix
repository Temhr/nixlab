
{ config, lib, pkgs, modulesPath, ... }:

{
  fileSystems."/home" =
    { device = "/dev/disk/by-label/home";
      fsType = "ext4";
    };

  fileSystems."/mirror" =
    { device = "/dev/disk/by-uuid/8c3b9f97-d5c5-4434-a2f6-6c12c4dc6ab3";
      fsType = "ext4";
    };

#  fileSystems."/mnt/hdd-r0" =
#    { device = "192.168.0.210:/hdd-r0";
#      fsType = "nfs";
#      options = [
#        "x-systemd.automount" "noauto"
#        "x-systemd.idle-timeout=60" # disconnects after 60 seconds
#      ];
#    };

#  systemd.tmpfiles.rules = [
#    "d /mirror 1770 root root "
#    "d /mnt 1770 root root "
#  ];

  boot.initrd.supportedFilesystems = [ "nfs" ];
  boot.initrd.kernelModules = [ "nfs" ];
  services.nfs.server.enable = true;
  services.nfs.server.exports = '' /mirror 0.0.0.0/255.255.255.0(rw,fsid=0,no_subtree_check) '';
  networking.firewall.allowedTCPPorts = [ 2049 ];
}
