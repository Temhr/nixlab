{self, ...}: {
  flake.nixosModules.hardw--zb17g4-p5 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-optional--driver-nvidia
      self.nixosModules.hardw--c-optional--mounts-extra
      self.nixosModules.hardw--c-optional--mount-data
      self.nixosModules.hardw--c-optional--mount-nfsvat
      self.nixosModules.hardw--c-optional--mount-nfszen
    ];
    # Choose between these choices: "none" "k" "p"
    driver-nvidia.quadro = "p";

    #mount-mirror.enable = true; #mounts mirror drive
  };
}
