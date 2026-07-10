{self, ...}: {
  flake.nixosModules.hosts--core--users-main = {
    config,
    lib,
    ...
  }: {
    options.nixlab.mainUser = lib.mkOption {
      type = lib.types.str;
      description = "The primary human user of this machine";
    };
    config.nixlab.mainUser =
      lib.mkDefault
      (self.lib.hostsMeta.${config.networking.hostName}.primaryUser or "temhr");
  };
  flake.nixosModules.hosts--core--users-hm = {config, ...}: {
    home-manager.users = self.lib.mkHomeUsersForHost config.networking.hostName;
  };
  flake.nixosModules.hosts--core--users-sys = {config, ...}: {
    users.users = self.lib.mkSystemUsersForHost config.networking.hostName;
  };
}
