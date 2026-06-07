{self, ...}: {
  flake.nixosModules.hardw--m720q-nas2 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-opt--mount-mirror
      self.nixosModules.hardw--c-opt--mount-mirnas1
    ];
  };
}
