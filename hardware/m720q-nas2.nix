{self, ...}: {
  flake.nixosModules.hardw--m720q-nas2 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-optional--mount-mirror
      self.nixosModules.hardw--c-optional--mount-mirnas1
    ];
  };
}
