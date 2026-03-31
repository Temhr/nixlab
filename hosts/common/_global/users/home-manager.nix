{
  self,
  config,
  ...
}: {
  home-manager.users.${config.nixlab.mainUser} =
    self."${config.nixlab.mainUser}-${config.networking.hostName}".
      "${config.nixlab.mainUser}-${config.networking.hostName}";
  # Pure name lookup. No path construction.
  # e.g. resolves to
  # self.homeModules.<user>-<host>
}
