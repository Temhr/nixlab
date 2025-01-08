{ config, lib, pkgs, ... }: {

  systemd.timers.git_pul = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "git_pul.service";
    };
  };
  systemd.services.git_pul = {
    description = "Git Repository Update Service";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/home/temhr/nixlab/bin/auto_pull.sh";
      User = "root";
    };
  };
}
