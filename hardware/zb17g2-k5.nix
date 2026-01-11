{  config, pkgs, ... }: {
  imports = [
    ./common/global
    ./common/optional
    ./common/optional/drives.nix
    ./common/optional/drives-additional.nix
    #./zb17g2-k5/disko-impermanence.nix
    #./zb17g2-k5/boilerplate.nix
  ];

  # Choose between these choices: "none" "k" "p"
  driver-nvidia.quadro = "k";

  mount-home.enable = true; #mounts home drive
  mount-shelf.enable = true; #mounts shelf drive in home directory
  #mount-mirror.enable = true; #mounts mirror drive
  #mount-mirk1.enable = true; #mounts mirk1 nfs
  #mount-mirk3.enable = true; #mounts mirk3 nfs

}
