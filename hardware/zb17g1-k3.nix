{self, ...}: {
  flake.nixosModules.hardw--zb17g1-k3 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-optional--driver-nvidia
      self.nixosModules.hardw--c-optional--mount-data
      self.nixosModules.hardw--c-optional--mount-mirror
      self.nixosModules.hardw--c-optional--mount-mirzen
    ];
    # Choose between these choices: "none" "k" "p"
    driver-nvidia.quadro = "k";
  };
}
