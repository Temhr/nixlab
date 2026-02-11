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
      
      ExecStart = pkgs.writeShellScript "check-display-manager" ''
        set -x  # Enable debug output - will show each command as it runs
        
        echo "Starting display-manager check at $(date)"
        
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
            logger -t dm-check "Display manager failed, rebooting"
            systemctl reboot
            exit 1
          fi
          
          # Check if compositor is running
          if pgrep -x kwin_wayland > /dev/null; then
            echo "Found kwin_wayland"
            
            # Check for either greeter or plasma
            if pgrep -x sddm-greeter > /dev/null || pgrep -x plasmashell > /dev/null; then
              echo "SUCCESS: Found UI component after $elapsed seconds"
              exit 0
            fi
          fi
          
          sleep $CHECK_INTERVAL
          elapsed=$((elapsed + CHECK_INTERVAL))
        done
        
        echo "TIMEOUT after $MAX_WAIT seconds"
        logger -t dm-check "Display timeout, rebooting"
        systemctl reboot
        exit 1
      '';
    };
  };

}
/*

# See what the script would detect right now
journalctl -u display-manager-startup-check -b

*/
