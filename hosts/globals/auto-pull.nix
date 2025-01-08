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
      ExecStart = "/etc/nixos/bin/hello.sh";
      User = "temhr";
    };
  };
}
