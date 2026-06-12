{self, ...}: {
  flake.nixosModules.hosts--hardw--power-management = {pkgs, ...}: {
    # Disable WD HDD power management (conditional on drive existence)
    systemd.services.disable-hdd-apm = {
      description = "Disable APM on data drive";
      wantedBy = ["multi-user.target"];
      before = ["local-fs.target"];
      unitConfig = {
        ConditionPathExists = "/dev/disk/by-label/data";
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.hdparm}/bin/hdparm -B 255 -S 0 /dev/disk/by-label/data";
        RemainAfterExit = true;
      };
    };

    boot.kernelParams = ["ahci.mobile_lpm_policy=1"];

    # Increase RAM cache for filesystem
    boot.kernel.sysctl = {
      "vm.dirty_ratio" = 60;
      "vm.dirty_background_ratio" = 40;
    };
  };
}
