{...}: {
  systemd.services.home-manager-temhr.serviceConfig.Environment = [
    "XDG_RUNTIME_DIR=/run/user/1000"
  ];
  services.nix-daemon.enable = true;
}
