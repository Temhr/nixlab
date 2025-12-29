{ config, pkgs, lib, ... }:

{
  # Disable APM on the WD drive - THIS IS THE CRITICAL FIX
  systemd.services.disable-hdd-apm = {
    description = "Disable APM on WD drive to prevent excessive load cycles";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.hdparm}/bin/hdparm -B 255 /dev/disk/by-label/data";
      RemainAfterExit = true;
    };
  };

  # Disable SATA link power management
  boot.kernelParams = [
    "ahci.mobile_lpm_policy=1"
  ];

  # Add hdparm to system packages
  environment.systemPackages = with pkgs; [
    hdparm
  ];
}
