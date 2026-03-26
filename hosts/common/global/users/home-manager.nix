{
  self,
  config,
  ...
}: {
  home-manager.users.${config.nixlab.mainUser} =
    self.homeModules.
      "${config.nixlab.mainUser}-${config.networking.hostName}";
  # Pure name lookup. No path construction.
  # e.g. resolves to
  # self.homeModules.<user>-<host>
}
