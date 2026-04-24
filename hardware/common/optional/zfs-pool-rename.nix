{...}: {
  flake.nixosModules.hardw--c-optional--zfs-pool-rename = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.zfs-pool-rename = {
      enable = lib.mkEnableOption {
        description = "Rename a ZFS pool by matching it against a known set of devices";
        default = false;
      };

      poolName = lib.mkOption {
        type = lib.types.str;
        description = "The desired pool name. If a pool with this name is already imported, the service exits immediately.";
      };

      devices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = ''
          The exact set of devices the target pool was created with (by-id paths
          preferred). The service scans all importable pools via `zpool import -v`
          and identifies the pool whose device set exactly matches this list.
        '';
      };
    };

    config = lib.mkIf config.zfs-pool-rename.enable (let
      cfg = config.zfs-pool-rename;

      # Build a newline-separated literal list of expected devices for the shell
      # script to compare against. Sorted so order doesn't matter at match time.
      expectedDevices = lib.concatStringsSep "\n" (builtins.sort builtins.lessThan cfg.devices);

      renameScript = pkgs.writeShellScript "zfs-pool-rename" ''
        set -euo pipefail
        DESIRED="${cfg.poolName}"

        # ── Step 1 ────────────────────────────────────────────────────────────
        # If the pool is already imported under the right name, nothing to do.
        if zpool list "$DESIRED" > /dev/null 2>&1; then
          echo "zfs-pool-rename: pool '$DESIRED' already present — skipping."
          exit 0
        fi

        # ── Step 2 ────────────────────────────────────────────────────────────
        # Build the expected device fingerprint (sorted, one per line).
        EXPECTED=$(printf '%s\n' ${lib.escapeShellArgs cfg.devices} | sort)

        # ── Step 3 ────────────────────────────────────────────────────────────
        # Scan all importable (not currently imported) pools and collect their
        # device lists. `zpool import -v` output looks like:
        #
        #    pool: oldname
        #      id: 1234567890
        #   state: ONLINE
        #  action: Online all devices with the pool or fix errors...
        #  config:
        #          oldname     ONLINE
        #            /dev/disk/by-id/scsi-abc  ONLINE
        #            /dev/disk/by-id/scsi-def  ONLINE
        #            ...
        #
        # We parse it into per-pool blocks and extract the device paths.

        MATCH_POOL=""

        # Use awk to emit "POOL:<name>" headers and "DEV:<path>" lines, then
        # process them pool-by-pool in the shell.
        while IFS= read -r line; do
          case "$line" in
            POOL:*)
              # Flush previous pool if we have one accumulated
              if [ -n "''${CURRENT_POOL:-}" ] && [ -n "''${CURRENT_DEVS:-}" ]; then
                SORTED_DEVS=$(printf '%s\n' $CURRENT_DEVS | sort)
                if [ "$SORTED_DEVS" = "$EXPECTED" ]; then
                  MATCH_POOL="$CURRENT_POOL"
                fi
              fi
              CURRENT_POOL="''${line#POOL:}"
              CURRENT_DEVS=""
              ;;
            DEV:*)
              CURRENT_DEVS="''${CURRENT_DEVS} ''${line#DEV:}"
              ;;
          esac
        done < <(
          zpool import -v 2>/dev/null | awk '
            /^   pool:/ { print "POOL:" $2 }
            /\/dev\//   { print "DEV:"  $1 }
          '
        )

        # Flush the last pool
        if [ -n "''${CURRENT_POOL:-}" ] && [ -n "''${CURRENT_DEVS:-}" ]; then
          SORTED_DEVS=$(printf '%s\n' $CURRENT_DEVS | sort)
          if [ "$SORTED_DEVS" = "$EXPECTED" ]; then
            MATCH_POOL="$CURRENT_POOL"
          fi
        fi

        # ── Step 4 ────────────────────────────────────────────────────────────
        # Evaluate the match result.

        if [ -z "$MATCH_POOL" ]; then
          echo "zfs-pool-rename: ERROR — no importable pool matched the expected device set:"
          printf '%s\n' ${lib.escapeShellArgs cfg.devices} | sort | sed 's/^/  /'
          echo "Cannot proceed; pool '$DESIRED' will not be imported."
          exit 1
        fi

        if [ "$MATCH_POOL" = "$DESIRED" ]; then
          # Shouldn't reach here (caught in Step 1), but be safe.
          echo "zfs-pool-rename: pool '$DESIRED' already has the correct name — skipping."
          exit 0
        fi

        # ── Step 5 ────────────────────────────────────────────────────────────
        # Exactly one device-matched pool found under a different name — rename it.
        echo "zfs-pool-rename: matched pool '$MATCH_POOL' by device fingerprint."
        echo "zfs-pool-rename: renaming '$MATCH_POOL' -> '$DESIRED'..."
        zpool import "$MATCH_POOL" "$DESIRED"
        echo "zfs-pool-rename: rename complete."
      '';
    in {
      systemd.services.zfs-pool-rename = {
        description = "Rename ZFS pool to '${cfg.poolName}' by device fingerprint";
        wantedBy    = ["zfs-import.target"];
        before      = ["zfs-import-${cfg.poolName}.service" "zfs-import.target"];
        after       = ["systemd-udev-settle.service"];
        path        = [config.boot.zfs.package];
        serviceConfig = {
          Type            = "oneshot";
          RemainAfterExit = true;
          ExecStart       = toString renameScript;
        };
      };
    });
  };
}
