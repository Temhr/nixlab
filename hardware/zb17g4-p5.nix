{ ... }: {
  imports = [
    ./common/global
    ./common/optional
    ./common/optional/drives.nix
    ./common/optional/drives-additional.nix
  ];

  # Choose between these choices: "none" "k" "p"
  driver-nvidia.quadro = "p";

  mount-home1.enable = true; #mounts home drive
  mount-shelf.enable = true; #mounts shelf drive in home directory
  #mount-mirror.enable = true; #mounts mirror drive
  mount-mirk1.enable = true; #mounts mirk1 nfs
  mount-mirk3.enable = true; #mounts mirk3 nfs

}
