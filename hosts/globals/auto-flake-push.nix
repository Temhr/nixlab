{ config, lib, pkgs, ... }:
let
  flakegitpushShellScript = pkgs.writeShellScript "nixlab-flake-git-push" ( builtins.readFile ../../bin/nixlab-flake-git-push.sh );
in
{
  systemd.timers.flake-push = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      Unit = "flake-push.service";
    };
  };

  systemd.services.flake-push = {
    description = "script write";
    serviceConfig = {
      ExecStart = flakegitpushShellScript;
      Type = "oneshot";
      User = "temhr";
    };
    startAt = "*:0/5";
  };
}
