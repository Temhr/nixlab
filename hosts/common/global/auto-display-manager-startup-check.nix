{ ... }: {

  # Create a custom service that checks if display-manager started successfully
  # This runs once at boot and reboots the system if display-manager failed
  # or took an unreasonably long time to start
  systemd.services.display-manager-startup-check = {

    # Human-readable description shown in systemctl status
    description = "Check if display manager started successfully at boot";

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
      # This is a shell script that checks display-manager status
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
          # Check if display-manager service is in "active" state
          # systemctl is-active returns:
          #   - exit code 0 if service is running
          #   - non-zero if service failed/inactive
          if systemctl is-active --quiet display-manager.service; then
            # Success! display-manager is running
            echo "Display manager started successfully after $elapsed seconds"
            exit 0  # Exit with success code, we're done
          fi

          # Check if display-manager has completely failed (not just still starting)
          # "failed" state means it tried to start and crashed/errored
          # This is different from "activating" (still starting up)
          if systemctl is-failed --quiet display-manager.service; then
            # display-manager explicitly failed - no point waiting longer
            echo "Display manager FAILED at boot after $elapsed seconds"
            logger -t display-manager-check "Display manager failed state detected, triggering reboot"
            systemctl reboot
            exit 1
          fi

          # display-manager hasn't started yet, but hasn't failed either
          # Probably still initializing - wait a bit longer
          sleep $CHECK_INTERVAL
          elapsed=$((elapsed + CHECK_INTERVAL))

          # Optional: print progress so you can see what's happening in logs
          echo "Still waiting... ($elapsed/$MAX_WAIT seconds)"
        done

        # If we get here, we've waited MAX_WAIT seconds and display-manager
        # still isn't active - this is abnormal even for slow systems
        echo "Display manager did not start within $MAX_WAIT seconds, rebooting system..."
        logger -t display-manager-check "Display manager timeout after $MAX_WAIT seconds, triggering reboot"

        # Trigger an immediate system reboot
        # Something is seriously wrong if it takes this long
        systemctl reboot
        exit 1
      '';
    };
  };
}

/*

# Watch the logs during boot
journalctl -u display-manager-startup-check -f

# Check after boot
systemctl status display-manager-startup-check
