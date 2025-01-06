
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
  fileSystems."/mnt/mirbase" =
    { device = "192.168.0.201:/mirror";
      fsType = "nfs";
      options = [
        "x-systemd.automount" "noauto"
        "x-systemd.after=network-online.target"
        "x-systemd.idle-timeout=60" # disconnects after 60 seconds
      ];
    };
  systemd.tmpfiles.rules = [
    "d /mirror 1744 temhr users "
    "d /mnt 1744 temhr users "
  ];

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
    allowedTCPPorts = [ 111  2049 4000 4001 4002 20048 ];
    allowedUDPPorts = [ 111  2049 4000 4001 4002 20048 ];
  };
}
