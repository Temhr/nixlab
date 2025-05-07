{ pkgs, ... }:
let
  GitPullShellScript = pkgs.writeShellScript "auto-git-pull" ( builtins.readFile ../../scripts/auto-git-pull.sh );
in
{
  systemd.timers.git-pull = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "60min";
      Unit = "git-pull.service";
    };
  };

  systemd.services.git-pull = {
    description = "Hourly nixlab git pull";
    serviceConfig = {
      ExecStart = GitPullShellScript;
      Type = "oneshot";
      User = "temhr";
    };
  };
}
