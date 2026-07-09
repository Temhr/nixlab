{...}: {
  flake.homeModules.home--core--system = {...}: {
    systemd.user.startServices = "suggest";
  };
}
