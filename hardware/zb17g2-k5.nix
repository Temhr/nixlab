{ ... }: {
  imports = [
    ./common/global
    ./common/optional
    ./zb17g2-k5
  ];

  # Choose between these choices: "none" "k" "p"
  driver-nvidia.quadro = "k";

}
