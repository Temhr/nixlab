{ config, lib, pkgs, ... }:
let
  nixBuildScript = pkgs.writeShellScript "buildScript" ''
      nixos-rebuild switch --flake /home/temhr/nixlab
    '';
in
{
  systemd.timers.nix-build = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "nix-build.service";
    };
  };

  systemd.services.nix-build = {
    description = "Build nix, then switch";
    serviceConfig = {
      ExecStart = nixBuildScript;
      Type = "oneshot";
      User = "root";
    };
  };
}
