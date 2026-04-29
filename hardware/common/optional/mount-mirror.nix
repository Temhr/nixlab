{...}: {
  flake.nixosModules.hardw--c-optional--mount-mirror = {config, ...}: {
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
  };
}
