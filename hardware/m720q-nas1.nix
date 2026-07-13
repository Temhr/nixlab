{self, ...}: {
  flake.nixosModules.hardw--m720q-nas1 = {...}: {
    imports = [
      (self.lib.mkHardwareProfile "m720q-nas1") # explicit — no config lookup, no ambiguity
      self.nixosModules.hardw--mounts--zfs-raidz1-pool
      self.nixosModules.hardw--mounts--mirror-peer
    ];
    mirrorPeers = ["nixnas2"];
    zfsRaidz1Pool = {
      enable = true;
      nfs.enable = true;
      poolName = "tanks";
      mountPoint = "/mirror";
      devices = [
        "/dev/disk/by-id/scsi-35000cca073b298e0"
        "/dev/disk/by-id/scsi-35000cca073739368"
        "/dev/disk/by-id/scsi-35000cca073b28880"
        "/dev/disk/by-id/scsi-35000cca073b23fdc"
      ];
      enableMonitoring = true;
      #alertEmail = "your-email@example.com";  # Optional: for email alerts
    };
  };
}
