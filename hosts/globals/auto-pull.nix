{ config, lib, pkgs, ... }: {

  systemd.timers.git-pull = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "git-pull.service";
    };
  };
  systemd.services.git-pull = {
    description = "Git Repository Update Service";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/home/temhr/nixlab/bin/auto-pull.sh";
      User = "temhr";
    };
  };
}
