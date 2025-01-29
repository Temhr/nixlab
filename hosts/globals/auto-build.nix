{ config, lib, pkgs, ... }:

let
    myscript = pkgs.writeShellScript "hi.sh" ''
      /run/current-system/sw/bin/home-manager switch
    '';
in

{
  system.autoUpgrade = {
    enable = true;
    operation = "switch"; #switch or boot
    flake = "github:Temhr/nixlab"; #Flake URI of the NixOS configuration to build
    allowReboot = false;
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

  systemd.services.hm-build = {
    description = "script write";
    serviceConfig ={
      ExecStart = myscript;
      Type = "oneshot";
      User = "temhr";
    };
    #startAt = "*:0/2";
  };
}
