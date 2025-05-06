{ config, lib, pkgs, ... }:
let
  GitPullShellScript = pkgs.writeShellScript "auto-git-pull" ( builtins.readFile ../../scripts/auto-git-pull.sh );
in
{
  systemd.timers.autoGP = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "60min";
      Unit = "autoGP.service";
    };
  };

  systemd.services.autoGP = {
    description = "Hourly nixlab git pull";
    serviceConfig = {
      ExecStart = GitPullShellScript;
      Type = "oneshot";
      User = "temhr";
    };
  };
}
