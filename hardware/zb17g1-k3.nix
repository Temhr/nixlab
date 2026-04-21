{self, ...}: {
  flake.nixosModules.hardw--zb17g1-k3 = {...}: {
    imports = [
      self.nixosModules.hardw--c-global
      self.nixosModules.hardw--c-optional--driver-nvidia
      self.nixosModules.hardw--c-optional--mounts-extra
    ];
    # Choose between these choices: "none" "k" "p"
    driver-nvidia.quadro = "k";

    mount-shelf.enable = true; #mounts shelf drive in home directory
    mount-mirror.enable = true; #mounts mirror drive
    mount-mirk1.enable = true; #mounts mirk1 nfs
    #mount-mirk3.enable = true; #mounts mirk3 nfs
  };
}
