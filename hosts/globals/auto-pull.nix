{ config, lib, pkgs, rootPath, ... }:
let
  gitpullShellScript = pkgs.writeShellScript "nixlab-git-pull" ( builtins.readFile ../../bin/nixlab-git-pull.sh );
in
{
  systemd.timers.git-pull = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "15min";
      Unit = "git-pull.service";
    };
  };

  systemd.services.git-pull = {
    description = "script write";
    serviceConfig = {
      ExecStart = gitpullShellScript;
      Type = "oneshot";
      User = "temhr";
    };
  };



  systemd.timers.a = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "a.service";
    };
  };

  systemd.services.a = {
    description = "script write";
    serviceConfig = {
      ExecStart = "${rootPath}bin/recycle/hello.sh";
      Type = "oneshot";
      User = "temhr";
    };
  };
}
