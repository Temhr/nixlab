{self, ...}: {
  flake.nixosModules.hardw--m720q-nas1 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-optional--mounts-extra
    ];

    networking.hostId = "c6e98cd9";
    #mount-shelf.enable = true; #mounts shelf drive in home directory
    mount-zfs-4dz1 = {
      enable = true;
      poolName = "mirror";
      devices = [
        "/dev/disk/by-id/scsi-35000cca073b298e0"
        "/dev/disk/by-id/scsi-35000cca073739368"
        "/dev/disk/by-id/scsi-35000cca073b28880"
        "/dev/disk/by-id/scsi-35000cca073b23fdc"
      ];
      enableMonitoring = true;
      #alertEmail = "your-email@example.com";  # Optional: for email alerts
    };
    #mount-mirror.enable = true; #mounts mirror drive
    mount-mirk1.enable = true; #mounts mirk1 nfs
    mount-mirk3.enable = true; #mounts mirk3 nfs
  };
}
