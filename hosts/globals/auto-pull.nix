#working shell script trigger .nix file

{ config, lib, pkgs, ... }:

let
  myscript = pkgs.writeShellScript "hello" ( builtins.readFile ../../bin/hello.sh );
in
{
  systemd.timers.a = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "d.service";
    };
  };

  systemd.services.d = {
    description = "script write";
    serviceConfig = {
      ExecStart = myscript;
      Type = "oneshot";
      User = "temhr";
    };
  };
}
