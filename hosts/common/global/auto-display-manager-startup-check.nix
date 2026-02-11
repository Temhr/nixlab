{ pkgs, ... }: {
  # Create a custom service that checks if display-manager AND Wayland GUI are working
  # This runs IMMEDIATELY after display-manager starts with a SHORT timeout
  # WAYLAND-ONLY VERSION with support for automatic login
  systemd.services.display-manager-startup-check = {
    
    # Human-readable description shown in systemctl status
    description = "Check if display manager and Wayland GUI started successfully at boot";
    
    # When this service should run in the boot sequence
    # ONLY wait for display-manager.service - nothing else
    # This makes us run as early as possible
    after = [ "display-manager.service" ];
    
    # Make this a REQUIRED dependency for display-manager to be considered "started"
    # This is more aggressive than "before" - it blocks display-manager completion
    requiredBy = [ "display-manager.service" ];
    
    # Attach this service to display-manager.target
    # This ensures it runs in the display-manager phase, not later
    wantedBy = [ "display-manager.target" ];
    
    serviceConfig = {
      # "oneshot" means this service runs once and exits
      # Unlike "simple" services that run continuously
      # Perfect for one-time startup checks
      Type = "oneshot";
      
      # RemainAfterExit means systemd considers this service "active" even after
      # the script finishes successfully. This prevents it from running again.
      # Once it succeeds, it stays in "active" state and won't re-run.
      RemainAfterExit = true;
      
      # The actual command this service runs
      # This is a shell script that checks display-manager status AND Wayland GUI
      ExecStart = pkgs.writeShellScript "check-display-manager" ''
        # Maximum time to wait - MUCH SHORTER now
        # We want this to complete quickly, before you can even login
        # 30-45 seconds should be enough for display-manager to show SOMETHING
        # If your system is slow, increase to 60, but not more
        MAX_WAIT=45
        
        # How long to wait between each check (in seconds)
        # Check every 2 seconds for faster detection
        CHECK_INTERVAL=2
        
        # Counter to track how long we've been waiting
        elapsed=0
        
        echo "EARLY CHECK: Verifying display-manager startup (timeout: $MAX_WAIT seconds)..."
        
        # Give display-manager a brief moment to initialize
        # Don't check immediately - let it start up
        sleep 5
        
        # Loop: check repeatedly until we confirm Wayland GUI is working or we timeout
        while [ $elapsed -lt $MAX_WAIT ]; do
          
          # FIRST CHECK: Is the display-manager service in failed state?
          # "failed" state means it tried to start and crashed/errored
          # This catches immediate crashes
          if systemctl is-failed --quiet display-manager.service; then
            # display-manager explicitly failed - reboot immediately
            echo "FAILURE: Display manager service failed after $elapsed seconds"
            logger -t display-manager-check "Display manager failed state detected, triggering reboot"
            systemctl reboot
            exit 1
          fi
          
          # SECOND CHECK: Is the display-manager service active?
          if systemctl is-active --quiet display-manager.service; then
            
            # CHECK FOR WAYLAND COMPOSITOR
            # KWin Wayland is the key - if this is running, the display system is working
            if pgrep -x kwin_wayland > /dev/null; then
              echo "✓ KWin Wayland compositor found after $elapsed seconds"
              
              # Now check if we can see EITHER login screen OR desktop
              # We just need ONE of these to prove GUI is visible
              
              if pgrep -x sddm-greeter > /dev/null; then
                # Login screen is showing - perfect!
                echo "✓ SDDM greeter detected - login screen is visible"
                echo "SUCCESS: Display system working after $elapsed seconds"
                exit 0
                
              elif pgrep -x plasmashell > /dev/null; then
                # Desktop already loaded (auto-login) - perfect!
                echo "✓ Plasmashell detected - desktop is loaded"
                echo "SUCCESS: Display system working after $elapsed seconds (auto-login)"
                exit 0
                
              else
                # KWin running but no UI yet - this is normal during startup
                # Keep waiting - UI should appear soon
                echo "KWin running, waiting for UI (greeter or Plasma)... ($elapsed seconds)"
              fi
              
            else
              # No compositor found - this is the "black screen" problem
              echo "No KWin Wayland compositor detected ($elapsed seconds)"
            fi
          else
            # display-manager not active yet
            echo "Waiting for display-manager service... ($elapsed seconds)"
          fi
          
          # Wait before next check
          sleep $CHECK_INTERVAL
          elapsed=$((elapsed + CHECK_INTERVAL))
        done
        
        # TIMEOUT: Something is wrong
        echo "TIMEOUT: Display system did not start properly within $MAX_WAIT seconds"
        echo "This check completed BEFORE you could login, so GUI is broken"
        
        # Log final state for debugging
        echo "Final state:"
        echo "  display-manager: $(systemctl is-active display-manager.service 2>&1)"
        echo "  kwin_wayland: $(pgrep -x kwin_wayland > /dev/null && echo 'YES' || echo 'NO')"
        echo "  sddm-greeter: $(pgrep -x sddm-greeter > /dev/null && echo 'YES' || echo 'NO')"
        echo "  plasmashell: $(pgrep -x plasmashell > /dev/null && echo 'YES' || echo 'NO')"
        
        logger -t display-manager-check "Display system timeout after $MAX_WAIT seconds, triggering reboot"
        
        # Trigger reboot
        systemctl reboot
        exit 1
      '';
    };
  };


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
