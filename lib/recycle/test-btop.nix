{ config, lib, pkgs, ... }: {

  environment.systemPackages = with pkgs; [
    btop  #A monitor of resources
  ];

}
