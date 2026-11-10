{...}: {
  flake.nixosModules.hardw--mounts--nfs-mirror-client = {
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
          device = "${allHosts.${peer}.address}:/";
          fsType = "nfs";
          options = [
            "x-systemd.automount"
            "noauto"
            "_netdev"
            "x-systemd.after=network-online.target"
            "x-systemd.idle-timeout=60"

            # Soft-ish behaviour: error out instead of blocking forever
            "soft"
            "timeo=50" # 5s per attempt (units are tenths of a second)
            "retrans=3" # retries before returning an error
            "x-systemd.mount-timeout=10"

            # Read-only, as your description says
            "ro"

            # Reasonable defaults for a LAN mirror
            "nfsvers=4.2"
            "nofail"
          ];
        };
      })
      config.mirrorPeers);
    config.systemd.network.wait-online.enable = true;
    config.systemd.tmpfiles.rules = ["d /mnt 1744 ${config.nixlab.mainUser} users"];
  };
}
