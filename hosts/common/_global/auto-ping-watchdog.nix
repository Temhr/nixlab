{pkgs, ...}: let
  # ─────────────────────────────────────────────────────────────────
  # Shared paths — referenced in both the watchdog and the toggle
  # ─────────────────────────────────────────────────────────────────
  inhibitFile = "/etc/ping-watchdog-inhibit";
  backoffFile = "/var/lib/ping-watchdog/backoff-exponent";

  # ─────────────────────────────────────────────────────────────────
  # Main watchdog script
  #
  # Backoff model (exponent E, starting at 0):
  #   window_secs   = 120 × 2^E          (2 min → 4 → 8 → 16 …)
  #   interval_secs =  10 × 2^E          (10 s  → 20 → 40 → 80 …)
  #   attempts      = window / interval  ≈ 12  (constant across cycles)
  #
  # On success  → reset exponent to 0
  # On reboot   → increment exponent by 1, persist to backoffFile
  # ─────────────────────────────────────────────────────────────────
  PingWatchdogShellScript = pkgs.writeShellScript "ping-watchdog" ''
        #!/usr/bin/env bash
        set -u

        # ── Constants ────────────────────────────────────────────────────
        PING_TARGETS=("8.8.8.8" "1.1.1.1" "9.9.9.9")
        BASE_WINDOW_SECS=120      # 2-minute window on first boot
        BASE_INTERVAL_SECS=10     # 10-second ping gap on first boot
        INHIBIT_FILE="${inhibitFile}"
        BACKOFF_FILE="${backoffFile}"
        LOG_TAG="ping-watchdog"
        REBOOT_WARN_SECS=60       # Broadcast warning this many seconds before rebooting

        # ── Helpers ──────────────────────────────────────────────────────
        log() {
            logger -t "$LOG_TAG" "$*"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
        }

        fmt_duration() {
            local secs=$1
            if   (( secs < 60  )); then echo "''${secs}s"
            elif (( secs < 3600 )); then echo "''$(( secs / 60 ))m ''$(( secs % 60 ))s"
            else echo "''$(( secs / 3600 ))h ''$(( (secs % 3600) / 60 ))m"
            fi
        }

        # Returns 0 if at least one target responds
        ping_internet() {
            for target in "''${PING_TARGETS[@]}"; do
                if /run/current-system/sw/bin/ping -c 2 -W 4 "$target" > /dev/null 2>&1; then
                    log "  ✓ $target responded"
                    return 0
                fi
                log "  ✗ No response from $target"
            done
            return 1
        }

        # ── Backoff exponent persistence ─────────────────────────────────
        read_exponent() {
            mkdir -p "$(dirname "$BACKOFF_FILE")"
            if [ -f "$BACKOFF_FILE" ]; then
                local val
                val=$(cat "$BACKOFF_FILE" 2>/dev/null)
                [[ "$val" =~ ^[0-9]+$ ]] && echo "$val" && return
            fi
            echo "0"
        }

        write_exponent() {
            mkdir -p "$(dirname "$BACKOFF_FILE")"
            echo "$1" > "$BACKOFF_FILE"
        }

        # ── Main ─────────────────────────────────────────────────────────
        main() {

            # ── Inhibit check ────────────────────────────────────────────
            if [ -f "$INHIBIT_FILE" ]; then
                log "Inhibit file present ($INHIBIT_FILE) — watchdog disabled, exiting."
                exit 0
            fi

            # ── Compute this cycle's timing from exponent ─────────────────
            local exponent
            exponent=$(read_exponent)

            local multiplier=$(( 1 << exponent ))                        # 2^E
            local window_secs=$(( BASE_WINDOW_SECS   * multiplier ))
            local interval_secs=$(( BASE_INTERVAL_SECS * multiplier ))
            local max_attempts=$(( window_secs / interval_secs ))        # ≈ 12

            log "════════════════════════════════════════════════════════"
            log "Ping watchdog starting"
            log "  Cycle          : $exponent  (×$multiplier)"
            log "  Window         : $(fmt_duration $window_secs)"
            log "  Ping interval  : $(fmt_duration $interval_secs)"
            log "  Max attempts   : $max_attempts"
            log "  Targets        : ''${PING_TARGETS[*]}"
            log "════════════════════════════════════════════════════════"

            # ── Boot-settle grace period ──────────────────────────────────
            # Only on cycle 0 (2-min window); longer windows don't need it
            # because later cycles imply repeated failures — start immediately.
            if (( exponent == 0 )); then
                log "Cycle 0: waiting 15 s for network to settle after boot..."
                sleep 15
            fi

            # ── Ping loop ─────────────────────────────────────────────────
            for attempt in $(seq 1 "$max_attempts"); do
                local elapsed_secs=$(( (attempt - 1) * interval_secs ))
                local remaining_secs=$(( window_secs - elapsed_secs ))
                log "Attempt $attempt/$max_attempts | elapsed $(fmt_duration $elapsed_secs) | $(fmt_duration $remaining_secs) left in window"

                if ping_internet; then
                    log "Internet reachable — resetting backoff to cycle 0."
                    write_exponent 0
                    log "Watchdog complete, exiting cleanly."
                    exit 0
                fi

                log "All targets failed."

                if (( attempt < max_attempts )); then
                    log "Next attempt in $(fmt_duration $interval_secs)..."
                    sleep "$interval_secs"
                fi
            done

            # ── Reboot path ───────────────────────────────────────────────
            local new_exponent=$(( exponent + 1 ))
            local next_window=$(( window_secs * 2 ))
            local next_interval=$(( interval_secs * 2 ))
            write_exponent "$new_exponent"

            log "Window exhausted after $(fmt_duration $window_secs) with no internet."
            log "Next cycle: $new_exponent — window $(fmt_duration $next_window), interval $(fmt_duration $next_interval)"
            log "Notifying users, rebooting in $(fmt_duration $REBOOT_WARN_SECS)..."

            /run/current-system/sw/bin/wall <<EOF
    [ping-watchdog] No internet detected after $(fmt_duration $window_secs).
    Rebooting in $(( REBOOT_WARN_SECS / 60 )) minute(s).  Next check window: $(fmt_duration $next_window).
    To cancel this reboot and disable the watchdog:
      sudo touch ${inhibitFile} && sudo shutdown -c
    EOF

            sleep "$REBOOT_WARN_SECS"

            # ── Last-chance check after warning window ────────────────────
            log "Final check before reboot..."
            if ping_internet; then
                log "Internet now reachable — aborting reboot, resetting to cycle 0."
                write_exponent 0
                exit 0
            fi

            log "Rebooting."
            /run/current-system/sw/bin/reboot
        }

        main "$@"
  '';

  # ─────────────────────────────────────────────────────────────────
  # Standalone toggle script  →  /usr/local/bin/watchdog
  #
  #   watchdog off      create inhibit file
  #   watchdog on       remove inhibit file
  #   watchdog reset    clear backoff exponent
  #   watchdog status   print current state
  # ─────────────────────────────────────────────────────────────────
  WatchdogToggleScript = pkgs.writeShellScript "watchdog" ''
    #!/usr/bin/env bash
    set -u

    INHIBIT_FILE="${inhibitFile}"
    BACKOFF_FILE="${backoffFile}"
    BASE_WINDOW_SECS=120
    BASE_INTERVAL_SECS=10

    fmt_duration() {
        local secs=$1
        if   (( secs < 60   )); then echo "''${secs}s"
        elif (( secs < 3600  )); then echo "''$(( secs / 60 ))m ''$(( secs % 60 ))s"
        else echo "''$(( secs / 3600 ))h ''$(( (secs % 3600) / 60 ))m"
        fi
    }

    require_root() {
        if [ "$EUID" -ne 0 ]; then
            echo "This command requires root. Try: sudo watchdog $*"
            exit 1
        fi
    }

    cmd="''${1:-status}"

    case "$cmd" in
        off)
            require_root "$@"
            touch "$INHIBIT_FILE"
            echo "Watchdog INHIBITED — no reboot will occur this boot."
            echo "Run 'sudo watchdog on' to re-enable."
            ;;
        on)
            require_root "$@"
            rm -f "$INHIBIT_FILE"
            echo "Watchdog ENABLED."
            ;;
        reset)
            require_root "$@"
            rm -f "$BACKOFF_FILE"
            echo "Backoff exponent cleared — next cycle uses 2-min window / 10-sec interval."
            ;;
        status)
            echo "── Ping Watchdog Status ─────────────────────────────────"

            if [ -f "$INHIBIT_FILE" ]; then
                echo "  State       : INHIBITED  ('sudo watchdog on' to enable)"
            else
                echo "  State       : enabled"
            fi

            EXP=0
            if [ -f "$BACKOFF_FILE" ]; then
                val=$(cat "$BACKOFF_FILE" 2>/dev/null)
                [[ "$val" =~ ^[0-9]+$ ]] && EXP=$val
            fi

            MULT=$(( 1 << EXP ))
            WINDOW=$(( BASE_WINDOW_SECS   * MULT ))
            INTV=$(( BASE_INTERVAL_SECS * MULT ))
            ATTEMPTS=$(( WINDOW / INTV ))

            echo "  Backoff     : cycle $EXP  (×$MULT)"
            echo "  Window      : $(fmt_duration $WINDOW)"
            echo "  Interval    : $(fmt_duration $INTV)"
            echo "  Attempts    : ~$ATTEMPTS per window"
            echo "  Service     : $(systemctl is-active ping-watchdog 2>/dev/null || echo 'unknown')"
            echo "  Last log    :"
            journalctl -u ping-watchdog -n 5 --no-pager --output=short 2>/dev/null \
                | sed 's/^/              /' \
                || echo "              (no journal entries found)"
            echo "─────────────────────────────────────────────────────────"
            ;;
        *)
            echo "Usage: watchdog {on|off|reset|status}"
            echo ""
            echo "  on      Re-enable the watchdog (removes inhibit file)"
            echo "  off     Inhibit the watchdog — no reboot this boot"
            echo "  reset   Clear backoff exponent back to cycle 0"
            echo "  status  Show current state, timing, and recent logs"
            exit 1
            ;;
    esac
  '';
in {
  # ── Systemd service ───────────────────────────────────────────────
  systemd.services.ping-watchdog = {
    description = "Ping watchdog — reboot if no internet, exponential backoff window";
    after = ["network.target" "network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = PingWatchdogShellScript;
      Type = "oneshot";
      User = "root";
      TimeoutStartSec = "infinity"; # Never kill mid-run, window can be hours
    };
    path = [pkgs.iputils pkgs.util-linux];
  };

  # ── Install toggle to /usr/local/bin/watchdog ─────────────────────
  environment.systemPackages = [
    (pkgs.stdenv.mkDerivation {
      name = "watchdog-toggle";
      phases = ["installPhase"];
      installPhase = ''
        mkdir -p $out/bin
        cp ${WatchdogToggleScript} $out/bin/watchdog
        chmod +x $out/bin/watchdog
      '';
    })
  ];
}
