#working shell script trigger .nix file; with writeShellScriptBin + shBang bash

{ config, lib, pkgs, ... }:

let
  myscript = pkgs.writeShellScriptBin "hi" ''
      #!/usr/bin/env bash
      echo "hi" >> /home/temhr/hi.txt
    '';
in
{
  systemd.timers.a = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "c.service";
    };
  };

  systemd.services.c = {
    description = "script write";
    serviceConfig = {
      ExecStart = myscript;
      Type = "oneshot";
      User = "temhr";
    };
  };
}
