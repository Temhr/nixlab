{...}: {

    systemd.user.units."drkonqi-coredump-pickup.service" = {
        text = ''
            [Unit]
            Description=Masked

            [Service]
            ExecStart=/bin/true
            Type=oneshot
        '';
    };

}
