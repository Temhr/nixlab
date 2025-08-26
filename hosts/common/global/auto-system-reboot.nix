{ config, pkgs, ... }:

let
  rebootScript = pkgs.writeShellScriptBin "conditional-reboot" ''
    STATE_FILE=/var/lib/conditional-reboot/last_reboot
    mkdir -p /var/lib/conditional-reboot

    # Current time
    now=$(date +%s)

    # If file exists, check last reboot
    if [ -f "$STATE_FILE" ]; then
      last=$(cat "$STATE_FILE")
      days_since=$(( (now - last) / 86400 ))
    else
      days_since=999
    fi

    # Must be between 2 and 4 days since last reboot
    if [ $days_since -lt 2 ]; then
      exit 0
    fi
    if [ $days_since -gt 4 ]; then
      should_reboot=1
    else
      # Random 50/50 chance to reboot today
      if [ $(( RANDOM % 2 )) -eq 0 ]; then
        should_reboot=1
      else
        should_reboot=0
      fi
    fi

    # Check if idle (no user input in last 30 minutes)
    idle_time=$(DISPLAY=:0 xprintidle 2>/dev/null || echo 0)
    if [ "$idle_time" -lt 1800000 ]; then
      should_reboot=0
    fi

    if [ "$should_reboot" -eq 1 ]; then
      echo $now > "$STATE_FILE"
      systemctl reboot
    fi
  '';
in {
  systemd.services.conditional-reboot = {
    description = "Conditional Random Reboot";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${rebootScript}/bin/conditional-reboot";
    };
  };

  systemd.timers.conditional-reboot = {
    description = "Timer for Conditional Random Reboot";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:00..04:59";
      Persistent = true;
    };
  };

  environment.systemPackages = [ pkgs.xprintidle ]; # needed for idle check
}
