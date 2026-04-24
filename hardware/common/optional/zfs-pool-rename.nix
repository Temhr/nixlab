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

      mountPoint = lib.mkOption {
        type = lib.types.str;
        description = ''
          The desired ZFS mountpoint property for the pool root dataset.
          After import/rename the service will reconcile the pool's stored
          mountpoint property to this value if it differs, so changing
          mountPoint in config takes effect on the next boot without any
          manual zfs-set commands.
        '';
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

      renameScript = pkgs.writeShellScript "zfs-pool-rename" ''
        set -euo pipefail
        DESIRED="${cfg.poolName}"
        DESIRED_MP="${cfg.mountPoint}"

        # ── Step 1 ────────────────────────────────────────────────────────────
        # If the pool is already imported under the right name, skip straight
        # to mountpoint reconciliation (Step 6).
        if zpool list "$DESIRED" > /dev/null 2>&1; then
          echo "zfs-pool-rename: pool '$DESIRED' already present — skipping rename."
        else

          # ── Step 2 ──────────────────────────────────────────────────────────
          # Build the expected device fingerprint: sorted, one path per line.
          # Baked in at eval time from the Nix devices list.
          EXPECTED=$(printf '%s\n' ${lib.escapeShellArgs cfg.devices} | sort)

          # ── Step 3 ──────────────────────────────────────────────────────────
          # Scan all importable (not currently imported) pools and collect their
          # device lists. `zpool import -v` produces output like:
          #
          #    pool: oldname
          #      id: 1234567890
          #   state: ONLINE
          #  config:
          #          oldname           ONLINE
          #            /dev/disk/by-id/scsi-abc  ONLINE
          #            /dev/disk/by-id/scsi-def  ONLINE
          #
          # Pure-shell parser — no awk or grep; only builtins + sort/sed from
          # coreutils (guaranteed in PATH via the service's path= setting).

          MATCH_POOL=""
          CURRENT_POOL=""
          CURRENT_DEVS=""

          # Flush the device list accumulated for CURRENT_POOL and check for match.
          flush_pool() {
            if [ -n "$CURRENT_POOL" ] && [ -n "$CURRENT_DEVS" ]; then
              SORTED_DEVS=$(printf '%s\n' $CURRENT_DEVS | sort)
              if [ "$SORTED_DEVS" = "$EXPECTED" ]; then
                MATCH_POOL="$CURRENT_POOL"
              fi
            fi
          }

          while IFS= read -r line; do
            case "$line" in
              POOL:*)
                flush_pool
                CURRENT_POOL="''${line#POOL:}"
                CURRENT_DEVS=""
                ;;
              DEV:*)
                CURRENT_DEVS="''${CURRENT_DEVS} ''${line#DEV:}"
                ;;
            esac
          done < <(
            # Inline pure-shell tokeniser: emit POOL:<n> and DEV:<path> tokens.
            zpool import -v 2>/dev/null | while IFS= read -r raw; do
              case "$raw" in
                *"pool: "*)
                  name="''${raw##*pool: }"
                  name="''${name%% *}"
                  printf 'POOL:%s\n' "$name"
                  ;;
                *"/dev/"*)
                  dev="''${raw#"''${raw%%[! ]*}"}"  # strip leading spaces
                  dev="''${dev%% *}"                 # take first token only
                  printf 'DEV:%s\n' "$dev"
                  ;;
              esac
            done
          )
          flush_pool  # flush the final pool block

          # ── Step 4 ────────────────────────────────────────────────────────
          if [ -z "$MATCH_POOL" ]; then
            echo "zfs-pool-rename: ERROR — no importable pool matched the expected device set:"
            printf '%s\n' ${lib.escapeShellArgs cfg.devices} | sort | sed 's/^/  /'
            echo "zfs-pool-rename: cannot proceed; pool '$DESIRED' will not be imported."
            exit 1
          fi

          # ── Step 5 ────────────────────────────────────────────────────────
          if [ "$MATCH_POOL" = "$DESIRED" ]; then
            # Pool is importable under the correct name — just import it.
            echo "zfs-pool-rename: importing pool '$DESIRED'..."
            zpool import "$DESIRED"
          else
            # Device-matched pool found under a different name — rename on import.
            echo "zfs-pool-rename: matched pool '$MATCH_POOL' by device fingerprint."
            echo "zfs-pool-rename: renaming '$MATCH_POOL' -> '$DESIRED'..."
            zpool import "$MATCH_POOL" "$DESIRED"
          fi
          echo "zfs-pool-rename: import complete."

        fi  # end of rename block

        # ── Step 6 ────────────────────────────────────────────────────────────
        # Reconcile the pool's stored mountpoint property with the configured
        # value. This makes mountPoint changes in Nix config self-healing on
        # next boot without any manual zfs-set commands.
        CURRENT_MP=$(zfs get -H -o value mountpoint "$DESIRED")
        if [ "$CURRENT_MP" != "$DESIRED_MP" ]; then
          echo "zfs-pool-rename: updating mountpoint: '$CURRENT_MP' -> '$DESIRED_MP'"
          zfs set mountpoint="$DESIRED_MP" "$DESIRED"
        else
          echo "zfs-pool-rename: mountpoint '$DESIRED_MP' already correct — skipping."
        fi
      '';
    in {
      systemd.services.zfs-pool-rename = {
        description = "Import/rename ZFS pool '${cfg.poolName}' and reconcile mountpoint";
        wantedBy    = ["zfs-import.target"];
        before      = ["zfs-import-${cfg.poolName}.service" "zfs-import.target"];
        after       = ["systemd-udev-settle.service"];
        # coreutils provides sort and sed used in the script
        path        = [config.boot.zfs.package pkgs.coreutils];
        serviceConfig = {
          Type            = "oneshot";
          RemainAfterExit = true;
          ExecStart       = toString renameScript;
        };
      };
    });
  };
}
