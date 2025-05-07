{ pkgs, ... }:
let
  GitPullShellScript = pkgs.writeShellScript "auto-git-pull" (
    builtins.readFile ../files/scripts/auto-git-pull.sh
  );
in
{
  systemd.user.timers.git-pull = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "60min";
      Unit = "git-pull.service";
    };
  };

  systemd.user.services.git-pull = {
    Unit = {
      Description = "Hourly nixlab git pull (user service)";
    };
    Service = {
      ExecStart = "${GitPullShellScript}";
      Type = "oneshot";
    };
  };
}
