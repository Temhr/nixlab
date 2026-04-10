{...}: {

  systemd.services.home-manager-temhr.serviceConfig.Environment = [
    "XDG_RUNTIME_DIR=/run/user/1000"
  ];
}
