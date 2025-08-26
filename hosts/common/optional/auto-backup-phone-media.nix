{ config, pkgs, ... }:
let
  photoMoveScript = pkgs.writeShellScriptBin "backup-phone-media" ''
    set -eu

    src="/mirror/phshare/photos/Camera"
    dst="/mirror/Hard-Drive-Backup/Pictures/phshare"

    mkdir -p "$dst"

    if [ -d "$src" ]; then
      shopt -s dotglob nullglob
      for f in "$src"/*; do
        [ -e "$f" ] || continue  # skip if nothing
        base=$(basename "$f")
        ts=$(date +%Y-%m-%d-%H-%M-%S)
        newname="$dst/${ts}-$base"

        # If the name already exists, append -1, -2, ...
        i=1
        while [ -e "$newname" ]; do
          newname="$dst/${ts}-$i-$base"
          i=$((i+1))
        done

        mv -- "$f" "$newname"
      done
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

