{ config, lib, pkgs, ... }: {

  systemd.timers.a = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "a.service";
    };
  };

  systemd.services."a" = {
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    path = config.aux.system.corePackages;
    unitConfig.RequiresMountsFor = cfg.configDir;
    script = lib.strings.concatStrings [
      "/run/current-system/sw/bin/nixos-upgrade-script --operation ${cfg.operation} "
      (lib.mkIf (cfg.configDir != "") "--flake ${cfg.configDir} ").content
      (lib.mkIf (cfg.user != "") "--user ${cfg.user} ").content
      (lib.mkIf (cfg.pushUpdates) "--update ").content
      (lib.mkIf (cfg.extraFlags != "") cfg.extraFlags).content
    ];
  };


  systemd.services.b = {
    description = "Git Repository Update Service";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''/tmp/hello.sh'';
      User = "root";
    };
  };
}
