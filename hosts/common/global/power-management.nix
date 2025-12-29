{ config, pkgs, ... }:

{
  # Fix WD HDD power management
  systemd.services.disable-hdd-apm = {
    description = "Disable APM on all HDDs";
    wantedBy = [ "multi-user.target" ];
    before = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      # Use disk labels since sd* names change
      ExecStart = pkgs.writeShellScript "disable-apm" ''
        for disk in /dev/disk/by-label/data; do
          if [ -b "$disk" ]; then
            ${pkgs.hdparm}/bin/hdparm -B 255 -S 0 "$disk"
          fi
        done
      '';
      RemainAfterExit = true;
    };
  };

  # Disable SATA power management
  boot.kernelParams = [
    "ahci.mobile_lpm_policy=1"
  ];

  # Add periodic filesystem sync for SD card health
  systemd.timers.sync-home = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "10m";
      Unit = "sync-home.service";
    };
  };

  systemd.services.sync-home = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/sync";
    };
  };
}
