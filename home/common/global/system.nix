{self, ...}: {
  flake.homeModules.common-global--system = {...}: {
    systemd.user.startServices = "suggest";
  };
}
