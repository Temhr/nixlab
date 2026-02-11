{ pkgs, ... }: {
  # Create a custom service that checks if display-manager AND the GUI are actually working
  # This runs once at boot and reboots the system if display-manager failed
  # or if the display isn't actually showing anything
  systemd.services.display-manager-startup-check = {

    # Human-readable description shown in systemctl status
    description = "Check if display manager and GUI started successfully at boot";

    # When this service should run in the boot sequence
    # "display-manager.service" = wait for display-manager to attempt starting
    # "multi-user.target" = wait for basic system to be ready
    after = [ "display-manager.service" "multi-user.target" ];

    # Attach this service to multi-user.target
    # This means it will run automatically during normal system startup
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      # "oneshot" means this service runs once and exits
      # Unlike "simple" services that run continuously
      # Perfect for one-time startup checks
      Type = "oneshot";

      # The actual command this service runs
      # This is a shell script that checks display-manager status AND actual GUI
      ExecStart = pkgs.writeShellScript "check-display-manager" ''
        # Maximum time to wait for display-manager to become active (in seconds)
        # 120 seconds = 2 minutes should be generous even for slow systems
        # Adjust this value based on your hardware:
        #   - Fast SSD system: 60 seconds might be enough
        #   - Older HDD system: 180 seconds for extra safety
        #   - Very slow system: 300 seconds (5 minutes)
        MAX_WAIT=120

        # How long to wait between each check (in seconds)
        # We'll check every 5 seconds to see if display-manager is up
        # Shorter interval = faster detection but more CPU cycles
        CHECK_INTERVAL=5

        # Counter to track how long we've been waiting
        elapsed=0

        echo "Waiting up to $MAX_WAIT seconds for display-manager to start..."

        # Loop: check repeatedly until display-manager is active or we timeout
        while [ $elapsed -lt $MAX_WAIT ]; do

          # FIRST CHECK: Is the display-manager service in failed state?
          # "failed" state means it tried to start and crashed/errored
          # This is different from "activating" (still starting up)
          if systemctl is-failed --quiet display-manager.service; then
            # display-manager explicitly failed - no point waiting longer
            echo "Display manager FAILED at boot after $elapsed seconds"
            logger -t display-manager-check "Display manager failed state detected, triggering reboot"
            systemctl reboot
            exit 1
          fi

          # SECOND CHECK: Is the display-manager service active?
          # If yes, proceed to check if GUI is actually working
          if systemctl is-active --quiet display-manager.service; then
            echo "Display manager service is active, checking if GUI is actually working..."

            # Give it a moment for the display to initialize
            # Sometimes the service reports active before display is ready
            sleep 3

            # CHECK 1: Is there an X server or Wayland compositor running?
            # These are the display servers that actually render the GUI
            # X11 check: look for Xorg or X process
            # Wayland check: look for a compositor (kwin_wayland for KDE)
            if pgrep -x Xorg > /dev/null || pgrep -x X > /dev/null || \
               pgrep -x kwin_wayland > /dev/null || pgrep -x kwin_x11 > /dev/null; then
              echo "Display server detected (Xorg or Wayland compositor running)"

              # CHECK 2: Is SDDM actually running?
              # SDDM is the login manager for KDE
              # If display-manager service is active but sddm isn't running,
              # something is wrong
              if pgrep -x sddm > /dev/null || pgrep -x sddm-greeter > /dev/null; then
                echo "SDDM login manager is running"

                # CHECK 3: Can we connect to the X display?
                # This verifies the display is actually accessible
                # DISPLAY=:0 is usually the first display
                # xset q queries the X server - if this succeeds, display is working
                if DISPLAY=:0 ${pkgs.xorg.xset}/bin/xset q &>/dev/null; then
                  echo "X display is accessible and responding"
                  echo "Display manager and GUI started successfully after $elapsed seconds"
                  exit 0  # All checks passed! Exit with success
                else
                  echo "WARNING: X display not accessible, but processes are running (might be Wayland)"
                  # For Wayland systems, we can't easily test the display
                  # But if we got this far (sddm + compositor running), probably OK
                  # Give it the benefit of the doubt
                  echo "Display manager started successfully after $elapsed seconds (Wayland mode)"
                  exit 0
                fi
              else
                echo "WARNING: Display server running but SDDM process not found after $elapsed seconds"
                # This is suspicious - display server without login manager
                # But keep waiting in case SDDM is just slow to start
              fi
            else
              echo "No display server detected yet after $elapsed seconds"
              # No Xorg or Wayland compositor - definitely not ready
              # Keep waiting
            fi
          else
            # display-manager service not active yet - still starting up
            echo "Display manager service not active yet after $elapsed seconds"
          fi

          # None of the success conditions met - wait longer
          sleep $CHECK_INTERVAL
          elapsed=$((elapsed + CHECK_INTERVAL))

          # Optional: print progress so you can see what's happening in logs
          echo "Still waiting... ($elapsed/$MAX_WAIT seconds)"
        done

        # If we get here, we've waited MAX_WAIT seconds and either:
        # - display-manager never became active
        # - display-manager is active but no GUI appeared
        # - SDDM process not running despite display-manager being active
        # All of these are abnormal - trigger reboot
        echo "Display manager/GUI did not start properly within $MAX_WAIT seconds"
        logger -t display-manager-check "Display manager/GUI timeout or failure after $MAX_WAIT seconds, triggering reboot"

        # Trigger an immediate system reboot
        # Something is seriously wrong
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
