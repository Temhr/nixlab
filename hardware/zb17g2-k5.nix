{self, ...}: {
  flake.nixosModules.hardw--zb17g2-k5 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-optional--driver-nvidia
      self.nixosModules.hardw--c-optional--mounts-extra
      self.nixosModules.hardw--c-optional--mount-data
      self.nixosModules.hardw--c-optional--mount-mirvat
      self.nixosModules.hardw--c-optional--mount-mirzen
    ];
    # Choose between these choices: "none" "k" "p"
    driver-nvidia.quadro = "k";

    #mount-mirror.enable = true; #mounts mirror drive
  };
}
