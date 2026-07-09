{
  self,
  config,
  ...
}: {
  home-manager.users = self.lib.mkHomeUsersForHost config.networking.hostName;
}
