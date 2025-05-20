{ ... }: {
  imports = [
    ./common/global
    ./common/optional
  ];

  # Choose between these choices: "none" "k" "p"
  driver-nvidia.quadro = "k";

}
