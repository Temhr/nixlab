#working shell script trigger .nix file

{ config, lib, pkgs, ... }:
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
}
