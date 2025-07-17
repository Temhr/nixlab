{ config, lib, pkgs, ... }:

let
  cfg = config.services.flakeAutoUpdate;
in {
  options.services.flakeAutoUpdate = {
    enable = lib.mkEnableOption "automatic flake updates";

    user = lib.mkOption {
      type = lib.types.str;
      default = "temhr";
      description = "User to run the service as";
    };

    flakePath = lib.mkOption {
      type = lib.types.path;
      default = "/home/temhr/nixlab";
      description = "Path to the flake directory";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/8:00";
      description = "Systemd timer interval (OnCalendar format)";
      example = "daily";
    };

    persistent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run missed timers on boot";
    };

    randomDelay = lib.mkOption {
      type = lib.types.str;
      default = "30m";
      description = "Random delay to spread load";
    };

    autoPush = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to automatically push changes to remote";
    };

    commitMessage = lib.mkOption {
      type = lib.types.str;
      default = "Auto-update flake.lock";
      description = "Commit message template";
    };

    beforeScript = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Script to run before flake update";
    };

    afterScript = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Script to run after successful update";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.flake-auto-update = {
      description = "Update flake and optionally push to remote";
      serviceConfig = {
        Type = "oneshot";
        WorkingDirectory = cfg.flakePath;
        Environment = [
          "PATH=${pkgs.lib.makeBinPath [ pkgs.nix pkgs.git pkgs.openssh pkgs.coreutils ]}"
          "HOME=/home/${cfg.user}"
        ];
        # User services have more relaxed security by default
        PrivateTmp = true;
        ReadWritePaths = [ cfg.flakePath "/home/${cfg.user}/.cache" ];
        NoNewPrivileges = true;
      };

      script = ''
        set -e

        # Function for logging
        log() {
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
        }

        log "Starting flake auto-update"

        # Run before script if provided
        ${lib.optionalString (cfg.beforeScript != "") ''
          log "Running before script"
          ${cfg.beforeScript}
        ''}

        # Check if we're in a git repository
        if ! git rev-parse --git-dir > /dev/null 2>&1; then
          log "ERROR: Not in a git repository"
          exit 1
        fi

        # Check for uncommitted changes
        if ! git diff-index --quiet HEAD --; then
          log "WARNING: Working directory has uncommitted changes, stashing them"
          git stash
          STASHED=true
        else
          STASHED=false
        fi

        # Pull from remote if autoPush is enabled
        ${lib.optionalString cfg.autoPush ''
          log "Pulling from remote"
          if ! git pull --rebase; then
            log "ERROR: Failed to pull from remote"
            exit 1
          fi
        ''}

        # Update the flake
        log "Updating flake"
        if ! nix flake update --flake ${cfg.flakePath}; then
          log "ERROR: Failed to update flake"
          exit 1
        fi

        # Check if there are any changes to flake.lock
        if ! git diff --quiet flake.lock; then
          log "Changes detected in flake.lock"

          # Stage and commit the changes
          git add flake.lock
          git commit -m "${cfg.commitMessage} ($(date '+%Y-%m-%d %H:%M:%S'))"

          ${lib.optionalString cfg.autoPush ''
            # Push to remote
            log "Pushing to remote"
            if ! git push; then
              log "ERROR: Failed to push to remote"
              exit 1
            fi
            log "Successfully pushed changes"
          ''}

          # Run after script if provided
          ${lib.optionalString (cfg.afterScript != "") ''
            log "Running after script"
            ${cfg.afterScript}
          ''}

          log "Flake update completed successfully"
        else
          log "No changes to flake.lock, nothing to commit"
        fi

        # Restore stashed changes if any
        if [ "$STASHED" = true ]; then
          log "Restoring stashed changes"
          git stash pop
        fi
      '';

      # Handle failures gracefully
      onFailure = [ "flake-auto-update-failure.service" ];
    };

    # Optional failure notification service
    systemd.user.services.flake-auto-update-failure = {
      description = "Handle flake auto-update failures";
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        echo "Flake auto-update failed at $(date)" >> /tmp/flake-update-failures.log
        # You could add email notifications, desktop notifications, etc. here
      '';
    };

    systemd.user.timers.flake-auto-update = {
      description = "Timer for flake auto-update";
      wantedBy = [ "default.target" ];  # Changed from timers.target
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = cfg.persistent;
        RandomizedDelaySec = cfg.randomDelay;
      };
    };

    # Enable lingering for the user so user services can run without login
    users.users.${cfg.user}.linger = true;
  };
}
