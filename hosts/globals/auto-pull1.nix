{ config, lib, pkgs, ... }:{

  systemd.timers.b = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "b.service";
    };
  };

  systemd.services.b = {
    description = "script write";
    myscript = pkgs.writeShellScriptBin "hi.sh" ''
      echo "hi" >> /home/temhr/hi.txt
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "temhr";
    };
  };


}




#  systemd.services."a" = {
#    description = "complex script trigger";
#    serviceConfig = {
#      Type = "oneshot";
#      User = "root";
#    };
#    path = config.aux.system.corePackages;
#    unitConfig.RequiresMountsFor = cfg.configDir;
#    script = lib.strings.concatStrings [
#      "/run/current-system/sw/bin/nixos-upgrade-script --operation ${cfg.operation} "
#      (lib.mkIf (cfg.configDir != "") "--flake ${cfg.configDir} ").content
#      (lib.mkIf (cfg.user != "") "--user ${cfg.user} ").content
#      (lib.mkIf (cfg.pushUpdates) "--update ").content
#      (lib.mkIf (cfg.extraFlags != "") cfg.extraFlags).content
#    ];
#  };

#  systemd.services.b = {
#    description = "script trigger";
#    serviceConfig = {
#      ExecStart = ''/tmp/hello.sh'';
#      Type = "oneshot";
#      User = "root";
#    };
#  };
