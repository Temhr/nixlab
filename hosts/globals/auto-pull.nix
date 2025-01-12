#working shell script trigger .nix file

{ config, lib, pkgs, ... }:

let
  myscript = pkgs.writeShellScript "hello" ( builtins.readFile ../../bin/nixos-operations-script.sh );
in
{
  systemd.timers."every5m" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "git-pull.service";
    };
  };

  systemd.services.git-pull = {
    description = "script write";
    serviceConfig = {
      ExecStart = myscript;
      Type = "oneshot";
      User = "temhr";
    };
  };
}
