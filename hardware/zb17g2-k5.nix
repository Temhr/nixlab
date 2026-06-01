{self, ...}: {
  flake.nixosModules.hardw--zb17g2-k5 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-optional--driver-nvidia
      self.nixosModules.hardw--c-optional--mount-data
      self.nixosModules.hardw--c-optional--mount-mirnas1
      self.nixosModules.hardw--c-optional--mount-mirnas2
    ];
    # Choose between these choices: "none" "l4" "l5" "s"
    driver-nvidia.driver-branch = "l4";
  };
}
