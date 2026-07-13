{
  self,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs) lib;
  hostsMeta = self.lib.hostsMeta;
  usersMeta = self.lib.usersMeta;

  mkSystemUser = username: let
    userMeta = usersMeta.${username};
  in
    {
      isNormalUser = userMeta.isNormalUser or true;
      openssh.authorizedKeys.keys = userMeta.sshAuthorizedKeys or [];
      extraGroups = userMeta.extraGroups or [];
    }
    // lib.optionalAttrs (userMeta.initialPassword or null != null) {
      initialPassword = userMeta.initialPassword;
    };

  mkSystemUsersForHost = hostName:
    assert lib.assertMsg
    (builtins.hasAttr hostName hostsMeta)
    "mkSystemUsersForHost: no hostsMeta entry found for '${hostName}'"; let
      meta = hostsMeta.${hostName};
    in
      lib.genAttrs meta.systemUsers (username:
        assert lib.assertMsg
        (builtins.hasAttr username usersMeta)
        "mkSystemUsersForHost: no usersMeta entry found for user '${username}' (host '${hostName}')";
          mkSystemUser username);

  mkHomeUser = {
    username,
    hostName,
  }: let
    userMeta = usersMeta.${username};
    override = userMeta.hostOverrides.${hostName} or {};
    profile = override.profile or userMeta.defaultProfile;
    extraModules = override.extraModules or [];
  in {
    imports =
      [self.homeModules.home--profl--base]
      ++ lib.optional (profile == "desktop") self.homeModules.home--profl--desktop
      ++ extraModules;

    home = {
      inherit username;
      homeDirectory = "/home/${username}";
      enableNixpkgsReleaseCheck = false;
      stateVersion = "24.11";
    };
    programs.home-manager.enable = true;
    programs.git.enable = true;
    programs.git.settings.user.name = userMeta.gitName;
    programs.git.settings.user.email = userMeta.gitEmail;
  };

  mkHomeUsersForHost = hostName:
    assert lib.assertMsg
    (builtins.hasAttr hostName hostsMeta)
    "mkHomeUsersForHost: no hostsMeta entry found for '${hostName}'"; let
      meta = hostsMeta.${hostName};
    in
      lib.genAttrs meta.homeUsers (username:
        assert lib.assertMsg
        (builtins.hasAttr username usersMeta)
        "mkHomeUsersForHost: no usersMeta entry found for user '${username}' (host '${hostName}')";
          mkHomeUser {inherit username hostName;});
in {
  flake.lib = {inherit mkSystemUser mkSystemUsersForHost mkHomeUser mkHomeUsersForHost;};
}
