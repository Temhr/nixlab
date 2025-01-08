{ config, ... }: {

    systemd.timers."nixlab-repo-auto-update" = {
    wantedBy = [ "timers.target" ];
        timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "5m";
        Unit = "nixlab-repo-auto-update.service";
        };
    };
    systemd.services."nixlab-repo-auto-update" = {
        script = ''
            # Set error handling
            set -euo pipefail

            # Hardcoded repository path
            REPO_PATH="/home/temhr/nixlab"

            # Function to log messages with timestamp
            log_message() {
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
            }

            # Function to check if directory is a git repository
            check_git_repo() {
                if [ ! -d ".git" ]; then
                    log_message "Error: Not a git repository"
                    exit 1
                fi
            }

            # Function to check current branch
            get_current_branch() {
                git rev-parse --abbrev-ref HEAD
            }

            # Change to the repository directory
            cd "$REPO_PATH"

            # Verify we're in a git repository
            check_git_repo

            # Get current branch
            CURRENT_BRANCH=$(get_current_branch)
            log_message "Current branch: $CURRENT_BRANCH"

            # Fetch updates from remote
            log_message "Fetching updates..."
            git fetch origin "$CURRENT_BRANCH"

            # Get the latest commit hash from remote
            REMOTE_HASH=$(git rev-parse "origin/$CURRENT_BRANCH")
            LOCAL_HASH=$(git rev-parse HEAD)

            if [ "$REMOTE_HASH" != "$LOCAL_HASH" ]; then
                log_message "Updates found. Pulling changes..."

                # Check for local changes
                if ! git diff --quiet; then
                    log_message "Warning: Local changes detected. Stashing changes..."
                    git stash
                fi

                # Pull updates
                if git pull origin "$CURRENT_BRANCH"; then
                    log_message "Successfully updated repository"

                    # Apply stashed changes if any
                    if git stash list | grep -q "stash@{0}"; then
                        log_message "Applying stashed changes..."
                        git stash pop
                    fi
                else
                    log_message "Error: Failed to pull updates"
                    exit 1
                fi
            else
                log_message "Repository is already up to date"
            fi
        '';
        serviceConfig = {
            Type = "oneshot";
            User = "temhr";
        };
    };

}
