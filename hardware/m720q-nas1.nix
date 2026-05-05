{self, ...}: {
  flake.nixosModules.hardw--m720q-nas1 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-optional--mount-4dz1
      self.nixosModules.hardw--c-optional--mount-mirvat
      self.nixosModules.hardw--c-optional--mount-mirzen
    ];

    networking.hostId = "c6e98cd9";
    mount-zfs-4dz1 = {
      enable = true;
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
