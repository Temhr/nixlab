{self, ...}: {
  flake.nixosModules.hardw--zb15g2-k1 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-optional--driver-nvidia
      self.nixosModules.hardw--c-optional--mounts-extra
      self.nixosModules.hardw--c-optional--mount-data
      self.nixosModules.hardw--c-optional--mount-mirror
      self.nixosModules.hardw--c-optional--mount-mirvat
    ];
    # Choose between these choices: "none" "k" "p"
    driver-nvidia.quadro = "k";
  };
}
