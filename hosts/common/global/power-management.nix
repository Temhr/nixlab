{ config, pkgs, ... }:

{
  # CRITICAL: Disable ALL power management
  powerManagement = {
    enable = false;
  };

  # Disable aggressive SATA link power management
  boot.kernelParams = [
    "ahci.mobile_lpm_policy=1"  # Maximum performance
    "libata.force=noncq"  # Disable NCQ if still having issues
  ];

  # Disable APM (Advanced Power Management) on WD drive
  # This prevents the aggressive head parking
  systemd.services.disable-hdd-apm = {
    description = "Disable APM on WD drive to prevent excessive load cycles";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.hdparm}/bin/hdparm -B 255 /dev/sdb";
      RemainAfterExit = true;
    };
  };

  # More frequent syncs to prevent data loss
  boot.kernel.sysctl = {
    "vm.dirty_expire_centisecs" = 500;
    "vm.dirty_writeback_centisecs" = 100;
  };

  # Enable SMART monitoring
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications = {
      wall.enable = true;
    };
  };
}
