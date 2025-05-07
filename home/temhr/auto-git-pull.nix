{ pkgs, ... }:
let
  GitPullShellScript = pkgs.writeShellScript "auto-git-pull" (
    builtins.readFile ../files/scripts/auto-git-pull.sh
  );
in
{
  systemd.user.timers.git-pull = {
    Unit = {
      Description = "Run git pull every hour";
    };
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "60min";
      Unit = "git-pull.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
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
