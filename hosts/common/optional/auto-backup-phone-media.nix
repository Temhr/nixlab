{ config, pkgs, ... }:

let
  photoMoveScript = pkgs.writeShellScriptBin "backup-phone-media" ''
    set -eu

    src="/mirror/phshare/photos/Camera"
    dst="/mirror/Hard-Drive-Backup/Pictures/phshare"

    mkdir -p "$dst"

    # Move everything (including hidden files)
    if [ -d "$src" ]; then
      shopt -s dotglob nullglob
      mv "$src"/* "$dst"/
    fi
  '';
in {
  systemd.services.backup-phone-media = {
    description = "Move photos from phshare to Hard-Drive-Backup";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${photoMoveScript}/bin/backup-phone-media";
    };
  };

  systemd.timers.backup-phone-media = {
    description = "Nightly photo move at 03:15";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "03:15";
      Persistent = true;
    };
  };
}
