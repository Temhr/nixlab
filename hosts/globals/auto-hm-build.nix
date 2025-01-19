{ config, lib, pkgs, ... }:
let
  hmbuildShellScript = pkgs.writeShellScript "nixlab-hm-build" ( builtins.readFile ../../bin/nixlab-hm-build.sh );
in
{
  systemd.timers.hm-build = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      Unit = "hm-build.service";
    };
  };

  systemd.services.hm-build = {
    description = "script write";
    serviceConfig = {
      ExecStart = hmbuildShellScript;
      Type = "oneshot";
      User = "temhr";
    };
    startAt = "*:0/5";
  };
}
