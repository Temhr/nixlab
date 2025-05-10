{ ... }: {
  imports = [
    ./common/global
    ./common/optional
  ];

  # Choose between these choices: "none" "k" "p"
  driver-nvidia.quadro = "k";

  mount-home.enable = true;
  #mount-mirror.enable = true;
  mount-mirk1.enable = true;
  mount-mirk3.enable = true;

}
