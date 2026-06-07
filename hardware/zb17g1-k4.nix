{self, ...}: {
  flake.nixosModules.hardw--zb17g1-k4 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-opt--driver-nvidia
      self.nixosModules.hardw--c-opt--mount-data
      self.nixosModules.hardw--c-opt--mount-mirnas1
      self.nixosModules.hardw--c-opt--mount-mirnas2
    ];
    # Choose between these choices: "none" "l470" "l535" "l580" "stable"
    driver-nvidia.driver-branch = "l470";
  };
}
