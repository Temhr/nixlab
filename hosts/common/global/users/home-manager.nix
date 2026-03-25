{
  self,
  config,
  ...
}: {
  home-manager.users.temhr =
    self.homeModules.
      "temhr-${config.networking.hostName}";
  # Pure name lookup. No path construction.
  # e.g. resolves to
  # self.homeModules.temhr-nixsun
}
