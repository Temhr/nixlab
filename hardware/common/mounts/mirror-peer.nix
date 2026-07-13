{...}: {
  flake.nixosModules.hardw--mounts--mirror-peer = {
    allHosts,
    config,
    lib,
    ...
  }: {
    options.mirrorPeers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Hostnames from hostsMeta to mount as read-only NFS mirrors under /mnt/mir<name>.";
    };
    config.fileSystems = lib.mkMerge (map (peer: {
        "/mnt/mir${peer}" = {
          device = "${allHosts.${peer}.address}:/mirror";
          fsType = "nfs";
          options = ["x-systemd.automount" "noauto" "_netdev" "x-systemd.after=network-online.target" "x-systemd.idle-timeout=60"];
        };
      })
      config.mirrorPeers);
    config.systemd.network.wait-online.enable = true;
    config.systemd.tmpfiles.rules = ["d /mnt 1744 ${config.nixlab.mainUser} user"];
  };
}
