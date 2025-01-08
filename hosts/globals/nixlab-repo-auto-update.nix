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
            # Navigate to your repository
            cd /home/temhr/nixlab || exit

            # Fetch the latest changes
            git fetch

            # Check if there are changes in the remote repository
            LOCAL=$(git rev-parse @)
            REMOTE=$(git rev-parse @{u})

            if [ "$LOCAL" != "$REMOTE" ]; then
                date >> /home/temhr/log-nixlab.txt
                git pull
            fi
        '';
        serviceConfig = {
            Type = "oneshot";
            User = "temhr";
        };
    };

}
