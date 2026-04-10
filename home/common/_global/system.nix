{...}: {
systemd.services.home-manager-temhr.serviceConfig.Environment = [
  "XDG_RUNTIME_DIR=/run/user/%U"  # %U expands to the user's UID
];
  systemd.user.startServices = "suggest";

}
