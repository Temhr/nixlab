{ pkgs, ... }: {

  systemd.services.display-manager-startup-check = {
    description = "Check if display manager and Wayland GUI started successfully at boot";
    
    # Simple dependencies - just wait for display-manager
    after = [ "display-manager.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      
      # Set a systemd-level timeout as a safety net
      # If script takes longer than this, systemd kills it
      TimeoutStartSec = "60s";
      
      # BOOT LOOP PROTECTION:
      # StartLimitBurst = maximum number of times this service can fail
      # StartLimitIntervalSec = time window for counting failures
      # If this service triggers 3 reboots within 10 minutes, systemd will
      # STOP trying to start it and your system will boot normally (without the check)
      # This prevents infinite boot loops
      StartLimitBurst = 3;
      StartLimitIntervalSec = "10min";
      
      ExecStart = pkgs.writeShellScript "check-display-manager" ''
        set -x  # Enable debug output - will show each command as it runs
        
        echo "Starting display-manager check at $(date)"
        
        # BOOT LOOP PROTECTION #1: Check reboot count
        # We store a counter file that tracks consecutive failed boots
        # If we've rebooted too many times recently, SKIP the check entirely
        COUNTER_FILE="/var/lib/dm-check-reboots"
        MAX_CONSECUTIVE_REBOOTS=3
        
        # Create directory if it doesn't exist
        mkdir -p /var/lib
        
        # Read current reboot count (or 0 if file doesn't exist)
        if [ -f "$COUNTER_FILE" ]; then
          REBOOT_COUNT=$(cat "$COUNTER_FILE")
          echo "Previous reboot count: $REBOOT_COUNT"
        else
          REBOOT_COUNT=0
          echo "No previous reboot count found"
        fi
        
        # If we've rebooted too many times, ABORT and let system boot normally
        if [ "$REBOOT_COUNT" -ge "$MAX_CONSECUTIVE_REBOOTS" ]; then
          echo "WARNING: Already rebooted $REBOOT_COUNT times recently"
          echo "SKIPPING display-manager check to prevent boot loop"
          echo "System will boot normally without automatic reboot protection"
          logger -t dm-check "Boot loop protection activated - skipping check after $REBOOT_COUNT reboots"
          
          # Reset counter after a delay (next boot will try again)
          # This happens in background so it doesn't block boot
          (sleep 300; echo 0 > "$COUNTER_FILE") &
          
          exit 0  # Exit successfully so boot continues normally
        fi
        
        # Increment reboot counter (will be used if we decide to reboot)
        NEW_COUNT=$((REBOOT_COUNT + 1))
        echo "If reboot is needed, this will be attempt #$NEW_COUNT"
        
        # Short timeout since we're checking early
        MAX_WAIT=40
        CHECK_INTERVAL=2
        elapsed=0
        
        # Initial wait for display-manager to start
        sleep 5
        
        while [ $elapsed -lt $MAX_WAIT ]; do
          echo "Check iteration: $elapsed seconds elapsed"
          
          # Check for failure
          if systemctl is-failed --quiet display-manager.service; then
            echo "FAILED: display-manager service is in failed state"
            echo "$NEW_COUNT" > "$COUNTER_FILE"
            logger -t dm-check "Display manager failed (reboot #$NEW_COUNT), rebooting"
            sleep 2  # Brief delay before reboot
            systemctl reboot
            exit 1
          fi
          
          # Check if compositor is running
          if pgrep -x kwin_wayland > /dev/null; then
            echo "Found kwin_wayland"
            
            # Check for either greeter or plasma
            if pgrep -x sddm-greeter > /dev/null || pgrep -x plasmashell > /dev/null; then
              echo "SUCCESS: Found UI component after $elapsed seconds"
              
              # SUCCESS! Reset the reboot counter
              # System booted successfully, so clear any previous failure count
              echo 0 > "$COUNTER_FILE"
              logger -t dm-check "Display manager started successfully, counter reset"
              
              exit 0
            fi
          fi
          
          sleep $CHECK_INTERVAL
          elapsed=$((elapsed + CHECK_INTERVAL))
        done
        
        # TIMEOUT - but check reboot count before rebooting
        echo "TIMEOUT after $MAX_WAIT seconds"
        echo "$NEW_COUNT" > "$COUNTER_FILE"
        logger -t dm-check "Display timeout (reboot #$NEW_COUNT), rebooting"
        sleep 2  # Brief delay before reboot
        systemctl reboot
        exit 1
      '';
    };
  };

}
/*
# manual override
sudo systemctl disable display-manager-startup-check

*/
