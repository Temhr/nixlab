{ config, lib, pkgs, ... }: {

  systemd.timers.git-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "git-update.service";
    };
  };

  systemd.services.git-update = {
    description = "Git Repository Update Service";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/home/temhr/nixlab/bin/auto-pull.sh";
      User = "root";
    };
  };
}
