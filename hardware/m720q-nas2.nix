{self, ...}: {
  flake.nixosModules.hardw--m720q-nas2 = {...}: {
    imports = [
      (self.lib.mkHardwareProfile "m720q-nas2") # explicit — no config lookup, no ambiguity
      self.nixosModules.hardw--mounts--legacy-nfs-mirror
      self.nixosModules.hardw--mounts--mirror-peer
    ];
    mirrorPeers = ["nixnas1"];
  };
}
