{ config, lib, pkgs, ... }: {

  systemd.timers.b = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "b.service";
    };
  };

  systemd.services.b = {
    description = "Git Repository Update Service";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = /tmp/hello.sh;
      User = "root";
    };
  };
}
