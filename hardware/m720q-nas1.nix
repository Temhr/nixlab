{self, ...}: {
  flake.nixosModules.hardw--m720q-nas1 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-optional--mounts-extra
    ];

    mount-home.enable = true; #mounts home drive
    #mount-shelf.enable = true; #mounts shelf drive in home directory
    #mount-mirror.enable = true; #mounts mirror drive
    mount-mirk1.enable = true; #mounts mirk1 nfs
    mount-mirk3.enable = true; #mounts mirk3 nfs
  };
}
