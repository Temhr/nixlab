{ config, lib, pkgs, ... }:{
  system.autoUpgrade = {
    enable = true;
    operation = "boot"; #switch or boot
    flake = "github:Temhr/nixlab"; #Flake URI of the NixOS configuration to build
    allowReboot = true;
    randomizedDelaySec = "30m";
    dates = "02:00";
    flags = [
      "--update-input"
      "nixpkgs"
      "-L" # print build logs
      #"--commit-lock-file"
      "--no-write-lock-file"
    ];
  };
}
