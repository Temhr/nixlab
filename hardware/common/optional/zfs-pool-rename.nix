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
          After import/rename the service reconciles the pool's stored mountpoint
          property to this value if it differs, making mountPoint changes in Nix
          config self-healing on next boot.
        '';
      };

      devices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = ''
          The exact set of devices the target pool was created with (full
          /dev/disk/by-id/ paths). The service strips the path prefix before
          comparing against what `zpool import` reports (bare scsi-* names),
          so full paths here and bare names in ZFS output both work correctly.
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
        # If the pool is already imported under the right name, skip to
        # mountpoint reconciliation (Step 6).
        if zpool list "$DESIRED" > /dev/null 2>&1; then
          echo "zfs-pool-rename: pool '$DESIRED' already present — skipping rename."
        else

          # ── Step 2 ──────────────────────────────────────────────────────────
          # Build the expected device fingerprint.
          # `zpool import` reports bare device names without any path prefix
          # (e.g. "scsi-35000cca073b298e0"), so strip everything up to and
          # including the last '/' from each configured device path.
          EXPECTED=$(
            printf '%s\n' ${lib.escapeShellArgs cfg.devices} \
              | sed 's|.*/||' \
              | sort
          )

          # ── Step 3 ──────────────────────────────────────────────────────────
          # Scan importable pools. Plain `zpool import` (no flags) output:
          #
          #    pool: tank
          #      id: 9599126087267335511
          #   state: ONLINE
          #  action: The pool can be imported...
          #  config:
          #          tank                        ONLINE
          #            raidz1-0                  ONLINE
          #              scsi-35000cca073b298e0  ONLINE
          #              scsi-35000cca073739368  ONLINE
          #              scsi-35000cca073b28880  ONLINE
          #              scsi-35000cca073b23fdc  ONLINE
          #
          # Leaf device lines are the deeply-indented entries whose first token
          # contains a '-' and is not a known vdev group keyword.

          MATCH_POOL=""
          CURRENT_POOL=""
          CURRENT_DEVS=""

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
            # Use default IFS word-splitting (read -r tok rest) so leading tabs
            # AND spaces are consumed. zpool import indents device lines with tabs,
            # which [! ] space-only stripping cannot handle.
            zpool import 2>/dev/null | while read -r tok rest; do
              case "$tok" in
                "pool:")
                  printf 'POOL:%s\n' "$rest"
                  ;;
                raidz*|mirror-*|spare*|log*|cache*|config:|action:|state:|id:|""|ONLINE|DEGRADED|FAULTED|OFFLINE|REMOVED|UNAVAIL)
                  : ;;
                *-*)
                  printf 'DEV:%s\n' "$tok"
                  ;;
              esac
            done
          )
          flush_pool

          # ── Step 4 ────────────────────────────────────────────────────────
          if [ -z "$MATCH_POOL" ]; then
            echo "zfs-pool-rename: ERROR — no importable pool matched the expected devices."
            echo "zfs-pool-rename: expected (basename):"
            printf '%s\n' ${lib.escapeShellArgs cfg.devices} | sed 's|.*/||' | sort | sed 's/^/  /'
            echo "zfs-pool-rename: importable pools seen:"
            zpool import 2>/dev/null | sed 's/^/  /' || echo "  (none)"
            echo "zfs-pool-rename: cannot proceed; pool '$DESIRED' will not be imported."
            exit 1
          fi

          # ── Step 5 ────────────────────────────────────────────────────────
          if [ "$MATCH_POOL" = "$DESIRED" ]; then
            echo "zfs-pool-rename: importing pool '$DESIRED'..."
            zpool import "$DESIRED"
          else
            echo "zfs-pool-rename: matched pool '$MATCH_POOL' by device fingerprint."
            echo "zfs-pool-rename: renaming '$MATCH_POOL' -> '$DESIRED'..."
            zpool import "$MATCH_POOL" "$DESIRED"
          fi
          echo "zfs-pool-rename: import complete."

        fi  # end rename/import block

        # ── Step 6 ────────────────────────────────────────────────────────────
        # Reconcile the pool's stored mountpoint property with the configured
        # value. Self-healing: changing mountPoint in Nix takes effect on next
        # boot without any manual zfs set commands.
        CURRENT_MP=$(zfs get -H -o value mountpoint "$DESIRED")
        if [ "$CURRENT_MP" != "$DESIRED_MP" ]; then
          echo "zfs-pool-rename: updating mountpoint '$CURRENT_MP' -> '$DESIRED_MP'"
          zfs set mountpoint="$DESIRED_MP" "$DESIRED"
        else
          echo "zfs-pool-rename: mountpoint '$DESIRED_MP' already correct — skipping."
        fi
      '';
    in {
      systemd.services.zfs-pool-rename = {
        description = "Import/rename ZFS pool '${cfg.poolName}' and reconcile mountpoint";
        wantedBy = ["zfs-import.target"];
        before = ["zfs-import-${cfg.poolName}.service" "zfs-import.target"];
        after = ["systemd-udev-settle.service"];
        path = [config.boot.zfs.package pkgs.coreutils];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = toString renameScript;
        };
      };
    });
  };
}
