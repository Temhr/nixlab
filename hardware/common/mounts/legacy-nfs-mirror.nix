# candidate to migrate onto the ZFS module later if nixnas2's disks ever get converted
{self, ...}: {
  flake.nixosModules.hardw--mounts--legacy-nfs-mirror = {config, ...}: {
    imports = [self.nixosModules.hardw--mounts--nfs-mirror-server];
    nfsMirrorServer.enable = true;
    fileSystems."/mirror" = {
      device = "/dev/disk/by-label/mirror";
      fsType = "ext4";
      options = ["defaults" "nofail" "x-systemd.device-timeout=10s"];
    };
    systemd.tmpfiles.rules = ["d /mirror 0775 ${config.nixlab.mainUser} users -"];
  };
}
