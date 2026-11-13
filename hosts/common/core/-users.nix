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
    config = {
      nixlab.mainUser =
        lib.mkDefault
        (self.lib.hostsMeta.${config.networking.hostName}.primaryUser or "temhr");
      assertions = [
        {
          assertion = builtins.hasAttr config.nixlab.mainUser (self.lib.mkSystemUsersForHost config.networking.hostName);
          message = "nixlab.mainUser '${config.nixlab.mainUser}' is not in systemUsers for this host";
        }
      ];
    };
  };

  flake.nixosModules.hosts--core--users-hm = {config, ...}: {
    home-manager.users = self.lib.mkHomeUsersForHost config.networking.hostName;
  };

  flake.nixosModules.hosts--core--users-sys = {
    config,
    lib,
    ...
  }: let
    hostName = config.networking.hostName;
  in {
    config = lib.mkMerge [
      {
        users.users = self.lib.mkSystemUsersForHost hostName;
        users.groups = self.lib.mkSystemGroupsForHost hostName;
      }
      (self.lib.mkSystemPolicyForHost hostName)
    ];
  };
}
