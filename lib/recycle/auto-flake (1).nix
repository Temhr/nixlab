{ config, lib, pkgs, ... }:
let
  nixBuildShellScript = pkgs.writeShellScript "nixlab-build" ( builtins.readFile ../../bin/nixlab-build.sh );
in
{
  systemd.timers.nix-build = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1440min";
      Unit = "nix-build.service";
    };
  };

  systemd.services.nix-build = {
    description = "Build nix, then switch";
    serviceConfig = {
      ExecStart = nixBuildShellScript;
      Type = "oneshot";
      User = "root";
    };
  };
}
