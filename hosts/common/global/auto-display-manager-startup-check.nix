{ pkgs, ... }: {
  # Create a custom service that checks if display-manager AND Wayland GUI are working
  # This runs EARLY at boot and reboots the system if display-manager failed
  # or if the display isn't actually showing anything
  # WAYLAND-ONLY VERSION (no X11 checks)
  systemd.services.display-manager-startup-check = {
    
    # Human-readable description shown in systemctl status
    description = "Check if display manager and Wayland GUI started successfully at boot";
    
    # When this service should run in the boot sequence
    # "display-manager.service" = wait for display-manager to attempt starting
    # NOTE: We do NOT wait for multi-user.target because that can take a while
    # We want to check as soon as display-manager attempts to start
    after = [ "display-manager.service" ];
    
    # This is CRITICAL: we want this check to be REQUIRED for multi-user.target
    # If this service fails (triggers reboot), the system won't reach multi-user
    # This ensures the check completes BEFORE user login
    before = [ "multi-user.target" ];
    
    # Attach this service to multi-user.target
    # This means it will run automatically during normal system startup
    wantedBy = [ "multi-user.target" ];
    
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
        # Maximum time to wait for display-manager to become active (in seconds)
        # 90 seconds should be enough - we want this to complete BEFORE user login
        # If your system is very slow, increase this, but keep it under the time
        # it takes you to login after seeing the login screen
        MAX_WAIT=90
        
        # How long to wait between each check (in seconds)
        # We'll check every 3 seconds - more frequent since this is time-sensitive
        CHECK_INTERVAL=3
        
        # Counter to track how long we've been waiting
        elapsed=0
        
        echo "Checking display-manager startup for Wayland (timeout: $MAX_WAIT seconds)..."
        
        # Loop: check repeatedly until we confirm Wayland GUI is working or we timeout
        while [ $elapsed -lt $MAX_WAIT ]; do
          
          # FIRST CHECK: Is the display-manager service in failed state?
          # "failed" state means it tried to start and crashed/errored
          # This catches immediate crashes
          if systemctl is-failed --quiet display-manager.service; then
            # display-manager explicitly failed - reboot immediately
            echo "Display manager FAILED at boot after $elapsed seconds"
            logger -t display-manager-check "Display manager failed state detected, triggering reboot"
            systemctl reboot
            exit 1
          fi
          
          # SECOND CHECK: Is the display-manager service active?
          # If yes, proceed to check if Wayland GUI is actually working
          if systemctl is-active --quiet display-manager.service; then
            echo "Display manager service is active after $elapsed seconds, verifying Wayland GUI..."
            
            # Give Wayland compositor a moment to initialize
            # Wayland compositors can take a second to fully start up
            sleep 2
            
            # CHECK FOR WAYLAND COMPONENTS:
            # For KDE Plasma on Wayland, we need to look for:
            # 1. kwin_wayland - the KDE Wayland compositor (this renders everything)
            # 2. sddm-greeter - the actual login screen UI
            # 
            # Note: SDDM itself (sddm process) manages the login, but sddm-greeter
            # is what actually displays on screen. If greeter is running, you can see it.
            
            if pgrep -x kwin_wayland > /dev/null; then
              echo "✓ KWin Wayland compositor is running"
              
              # Additional check: is the SDDM greeter running?
              # The greeter is what you actually see (the login screen)
              if pgrep -x sddm-greeter > /dev/null; then
                echo "✓ SDDM greeter (login screen) is running"
                echo "SUCCESS: Display manager and Wayland GUI started after $elapsed seconds"
                echo "Login screen should be visible now"
                exit 0  # Exit successfully - all checks passed!
              else
                echo "✓ KWin is running but SDDM greeter not found yet"
                # This might happen briefly during startup
                # kwin_wayland starts before sddm-greeter appears
                # Keep waiting - greeter should appear soon
              fi
              
            else
              # Display-manager claims to be active but no Wayland compositor found
              echo "Display manager active but KWin Wayland not running yet (after $elapsed seconds)"
              
              # Check if SDDM process itself exists
              # If SDDM exists but no compositor, it might be about to start one
              if pgrep -x sddm > /dev/null; then
                echo "SDDM process found, waiting for compositor to start..."
              fi
              # Keep looping - compositor might be slow to start
            fi
          else
            # display-manager service not active yet - still starting up
            echo "Waiting for display-manager service to become active... ($elapsed seconds)"
          fi
          
          # Wait before next check
          sleep $CHECK_INTERVAL
          elapsed=$((elapsed + CHECK_INTERVAL))
        done
        
        # TIMEOUT: If we get here, we've waited MAX_WAIT seconds and either:
        # - display-manager never became active, OR
        # - display-manager is active but no Wayland compositor is running, OR
        # - KWin is running but SDDM greeter never appeared
        # 
        # This is the "black screen" scenario - service running but nothing visible
        # OR compositor running but no actual login screen displayed
        echo "TIMEOUT: Display manager/Wayland GUI did not start properly within $MAX_WAIT seconds"
        
        # Log what we found for debugging
        echo "Final state check:"
        echo "  display-manager service: $(systemctl is-active display-manager.service)"
        echo "  kwin_wayland process: $(pgrep -x kwin_wayland > /dev/null && echo 'running' || echo 'NOT FOUND')"
        echo "  sddm-greeter process: $(pgrep -x sddm-greeter > /dev/null && echo 'running' || echo 'NOT FOUND')"
        
        logger -t display-manager-check "Wayland GUI timeout after $MAX_WAIT seconds, triggering reboot"
        
        # Trigger reboot - something is wrong
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
