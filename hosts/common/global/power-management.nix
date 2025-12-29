{ config, ... }:

{
  # Disable WD HDD power management (already have this)
  systemd.services.disable-hdd-apm = {
    description = "Disable APM on data drive";
    wantedBy = [ "multi-user.target" ];
    before = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.hdparm}/bin/hdparm -B 255 -S 0 /dev/disk/by-label/data";
      RemainAfterExit = true;
    };
  };

  boot.kernelParams = [ "ahci.mobile_lpm_policy=1" ];

  # Reduce writes to SD card - cache in RAM
  fileSystems."/home".options = [ "relatime" "noatime" ];

  # Move browser cache to tmpfs
  systemd.tmpfiles.rules = [
    "L+ /home/temhr/.cache - - - - /tmp/user-cache"
    "d /tmp/user-cache 0700 temhr users -"
  ];

  # Increase RAM cache for filesystem
  boot.kernel.sysctl = {
    "vm.dirty_ratio" = 60;
    "vm.dirty_background_ratio" = 40;
  };
}
