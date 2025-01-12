#working shell script trigger .nix file

{ config, lib, pkgs, ... }:
let
  myscript = pkgs.writeShellScript "nixlab-git-pull" ( builtins.readFile ../../bin/nixlab-git-pull.sh );
in
{
  systemd.timers."every15m" = {
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
      ExecStart = myscript;
      Type = "oneshot";
      User = "temhr";
    };
  };
}
