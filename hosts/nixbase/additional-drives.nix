
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
    "d /home/temhr/shelf 1744 temhr users "
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
