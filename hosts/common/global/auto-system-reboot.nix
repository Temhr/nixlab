{ config, pkgs, ... }:
let
  rebootScript = pkgs.writeShellScriptBin "system-reboot" ''
    STATE_FILE=/var/lib/system-reboot/last_reboot
    mkdir -p /var/lib/system-reboot
    now=$(date +%s)
    # Atomic read with fallback
    last=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    days_since=$(( (now - last) / 86400 ))

    # Skip if rebooted within 2 days
    [ $days_since -lt 2 ] && exit 0

    # Force reboot after 5 days, otherwise 33% chance (1 in 3)
    if [ $days_since -gt 5 ]; then
      should_reboot=1
    else
      should_reboot=$([ $(( RANDOM % 3 )) -eq 0 ] && echo 1 || echo 0)
    fi

    # Check for recent user activity (last 30 min)
    recent_activity=$(find /tmp /var/tmp -user "$(id -u 1000 2>/dev/null || echo 1000)" -newermt "30 minutes ago" 2>/dev/null | head -1)
    [ -n "$recent_activity" ] && should_reboot=0

    if [ "$should_reboot" -eq 1 ]; then
      # Atomic write
      echo $now > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
      systemctl reboot
    fi
  '';
in {
  systemd.services.system-reboot = {
    description = "Conditional Random Reboot";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${rebootScript}/bin/system-reboot";
    };
  };
  systemd.timers.system-reboot = {
    description = "Timer for Conditional Random Reboot";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:00..04:59";
      Persistent = true;
    };
  };
}
