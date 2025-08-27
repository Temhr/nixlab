{ config, pkgs, ... }:

let
  photoMoveScript = pkgs.writeShellScriptBin "backup-phone-media" ''
    set -euo pipefail

    src="/mirror/phshare/photos"
    dst="/mirror/Hard-Drive-Backup/Pictures/phshare"

    mkdir -p "$dst"

    if [ -d "$src" ]; then
      shopt -s nullglob
      for f in "$src"/*; do
        [ -e "$f" ] || continue  # nothing to do
        base=$(basename "$f")

        # skip hidden files/folders
        case "$base" in
          .* ) continue ;;
        esac

        ts=$(date +%Y-%m-%d-%H-%M-%S)

        newname="$dst/$ts-$base"
        i=1
        while [ -e "$newname" ]; do
          newname="$dst/$ts-$i-$base"
          i=$((i+1))
        done

        mv -- "$f" "$newname"
        echo "moved: $f -> $newname"
      done
    fi
  '';
in {
  systemd.services.backup-phone-media = {
    description = "Move photos from phshare to Hard-Drive-Backup";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${photoMoveScript}/bin/backup-phone-media";
      # Optional: ensure logs go to journal
      StandardOutput = "journal";
      StandardError = "journal";
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
