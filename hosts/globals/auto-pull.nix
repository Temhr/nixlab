{ config, lib, pkgs, inputs, ... }:
let
  gitpullShellScript = pkgs.writeShellScript "nixlab-git-pull" ( builtins.readFile ../../bin/nixlab-git-pull.sh );
in
{
  systemd.timers.git-pull = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "15min";
      Unit = "git-pull.service";
    };
  };

  systemd.services.git-pull = {
    description = "script write";
    serviceConfig = {
      ExecStart = gitpullShellScript;
      Type = "oneshot";
      User = "temhr";
    };
  };

  system.autoUpgrade = {
    enable = true;
    operation = "switch"; #switch or boot
    #flake = "github:Temhr/nixlab"; #Flake URI of the NixOS configuration to build
    flake = inputs.self.outPath;  #local repo
    allowReboot = false;
    #randomizedDelaySec = "5m";
    dates = "11:45";
    flags = [
      "--update-input"
      "nixpkgs"
      "-L" # print build logs
      "--commit-lock-file"
      #"--no-write-lock-file"
    ];
  };
}
