{ pkgs, ... }:
let
  flakeAutoUpdate = pkgs.writeShellScript "flakeAutoUpdate" (
    builtins.readFile ../../../home/files/scripts/auto-update-flake.sh
  );

  # Combined script that runs flake update first, then system upgrade
  preSystemUpdate = pkgs.writeShellScript "preSystemUpdate" ''
    #!/bin/bash
    echo "Running flake auto-update before system upgrade..."
    ${flakeAutoUpdate}

    echo "Starting system upgrade..."
    nixos-rebuild boot --flake github:Temhr/nixlab --update-input nixpkgs -L --no-write-lock-file
  '';
in
{
  # Disable the built-in auto-upgrade since we're handling it manually
  system.autoUpgrade.enable = false;

  # Create our own system upgrade service that runs flake update first
  systemd.services.custom-system-upgrade = {
    description = "Custom system upgrade with flake pre-update";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${preSystemUpdate}";
      User = "root";
    };
    # Run after network is available
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  systemd.timers.custom-system-upgrade = {
    description = "Timer for custom system upgrade";
    timerConfig = {
      OnCalendar = "02:00";
      RandomizedDelaySec = "30m";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };
}
