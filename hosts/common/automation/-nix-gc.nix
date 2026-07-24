{...}: {
  flake.nixosModules.hosts--autom--nix-gc = {pkgs, ...}: {
    ## Garbage collection to maintain low disk usage
    nix.gc = {
      automatic = true;
      dates = "*-*-* 02:00:00";
      options = "--delete-older-than 5d";
    };

    environment.systemPackages = [ pkgs.nix ]; # ensure nix-collect-garbage is available

    systemd.services.boot-gc = {
      description = "Garbage-collect old generations when /boot is nearly full";
      script = ''
        set -euo pipefail

        THRESHOLD=75

        usage=$(${pkgs.coreutils}/bin/df --output=pcent /boot | tail -1 | tr -dc '0-9')
        echo "Current /boot usage: ''${usage}%"

        if [ "$usage" -ge "$THRESHOLD" ]; then
          echo "Threshold exceeded, collecting garbage..."
          ${pkgs.nix}/bin/nix-collect-garbage -d

          # Retry the bootloader regen in case another switch-to-configuration
          # is holding the lock at the same moment.
          attempt=0
          until /run/current-system/bin/switch-to-configuration boot; do
            attempt=$((attempt + 1))
            if [ "$attempt" -ge 5 ]; then
              echo "Failed to acquire lock after $attempt attempts, giving up."
              exit 1
            fi
            echo "Lock busy, retrying in 15s (attempt $attempt)..."
            sleep 15
          done

          new_usage=$(${pkgs.coreutils}/bin/df --output=pcent /boot | tail -1 | tr -dc '0-9')
          echo "Usage after GC: ''${new_usage}%"
        else
          echo "Below threshold, nothing to do."
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "10min";
      };
    };

    systemd.timers.boot-gc = {
      description = "Timer for boot-gc";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnActiveSec = "10min";    # 10 min after the timer itself starts/is enabled
        OnUnitActiveSec = "1h";   # then hourly after each run
        Persistent = true;
      };
    };
  };
}
