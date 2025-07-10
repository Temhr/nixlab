{ ... }: {
    services.journald.extraConfig = ''
        SystemMaxUse=100M
        SystemMaxFileSize=10M
        SystemMaxFiles=10
        MaxRetentionSec=1month
    '';
}
