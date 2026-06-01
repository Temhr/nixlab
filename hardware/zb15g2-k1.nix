{self, ...}: {
  flake.nixosModules.hardw--zb15g2-k1 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-optional--driver-nvidia
      self.nixosModules.hardw--c-optional--mount-data
      self.nixosModules.hardw--c-optional--mount-mirnas1
      self.nixosModules.hardw--c-optional--mount-mirnas2
    ];
    # Choose between these choices: "none" "l470" "l535" "l580" "stable"
    driver-nvidia.driver-branch = "l470";
  };
}
