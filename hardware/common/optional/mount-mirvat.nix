{...}: {
  flake.nixosModules.hardw--c-optional--mount-mirvat = {
    allHosts,
    config,
    ...
  }: {
    fileSystems."/mnt/mirvat" = {
      device = "${allHosts.nixvat.address}:/mirror";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "_netdev"
        "x-systemd.after=network-online.target"
        "x-systemd.idle-timeout=60"
      ];
    };

    # Ensure network-online.target is actually waited for
    systemd.network.wait-online.enable = true;

    systemd.tmpfiles.rules = ["d /mnt 1744 ${config.nixlab.mainUser} user"];
  };
}
