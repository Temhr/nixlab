{ ... }: {
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

}
