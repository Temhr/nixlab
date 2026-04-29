{self, ...}: {
  flake.nixosModules.hardw--zb17g4-p5 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-optional--driver-nvidia
      self.nixosModules.hardw--c-optional--mounts-extra
      self.nixosModules.hardw--c-optional--mount-data
    ];
    # Choose between these choices: "none" "k" "p"
    driver-nvidia.quadro = "p";

    #mount-mirror.enable = true; #mounts mirror drive
    mount-mirk1.enable = true; #mounts mirk1 nfs
    mount-mirk3.enable = true; #mounts mirk3 nfs
  };
}
