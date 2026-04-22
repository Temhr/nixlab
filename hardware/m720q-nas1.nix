{self, ...}: {
  flake.nixosModules.hardw--m720q-nas1 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-optional--mounts-extra
    ];

    boot.supportedFilesystems = [ "zfs" ];
    networking.hostId = "c6e98cd9";

    #mount-shelf.enable = true; #mounts shelf drive in home directory
    mount-zfs-4dz1.enable = true; #mounts zmirror drive
    #mount-mirror.enable = true; #mounts mirror drive
    mount-mirk1.enable = true; #mounts mirk1 nfs
    mount-mirk3.enable = true; #mounts mirk3 nfs
  };
}
