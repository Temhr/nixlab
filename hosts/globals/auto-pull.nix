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
      ExecStart = "bash /home/temhr/nixlab/bin/auto-pull.sh";
      User = "temhr";
      # Add error handling and logging
      StandardOutput = "journal";
      StandardError = "journal";
      # Ensure working directory exists
      WorkingDirectory = "/home/temhr/nixlab";
      # Add some basic hardening
      ProtectSystem = "full";
      ProtectHome = "read-only";
      # Ensure script can be executed
      ExecStartPre = "${pkgs.coreutils}/bin/test -x /home/temhr/nixlab/bin/auto-pull.sh";
    };
  };
}
