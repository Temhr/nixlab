{
  self,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs) lib;
  hostsMeta = self.lib.hostsMeta;
  usersMeta = self.lib.usersMeta;

  getHost = fn: hostName:
    assert lib.assertMsg (hostsMeta ? ${hostName})
    "${fn}: no hostsMeta entry for '${hostName}'";
      hostsMeta.${hostName};

  getUser = fn: hostName: username:
    assert lib.assertMsg (usersMeta ? ${username})
    "${fn}: no usersMeta entry for '${username}' (host '${hostName}')";
      usersMeta.${username};

  systemUsersFor = hostName:
    lib.genAttrs (getHost "mkSystemUsersForHost" hostName).systemUsers
    (getUser "mkSystemUsersForHost" hostName);

  groupOf = u: u.account.group or "users";
  isPasswordless = u:
    (u.account.initialPassword or null) == "" || (u.account.hashedPassword or null) == "";

  # --- NixOS side ---------------------------------------------------------
  mkSystemUser = username: usersMeta.${username}.account;

  mkSystemUsersForHost = hostName:
    lib.mapAttrs (_: u: u.account) (systemUsersFor hostName);

  # One group per distinct primary group ("users" already exists in NixOS).
  mkSystemGroupsForHost = hostName:
    lib.mapAttrs' (_: u: lib.nameValuePair (groupOf u) (u.groupConfig or {}))
    (lib.filterAttrs (_: u: groupOf u != "users") (systemUsersFor hostName));

  # Derived policy: passwordless accounts are never allowed over SSH,
  # and PAM accepts empty passwords for the text console login.
  # Shape is fixed; only the values are conditional (mkIf), so it is
  # safe to use with config-derived hostName.
  mkSystemPolicyForHost = hostName: let
    names = lib.attrNames (lib.filterAttrs (_: isPasswordless) (systemUsersFor hostName));
    any = names != [];
  in {
    services.openssh.settings.DenyUsers = lib.mkIf any names;
    security.pam.services.login.allowNullPassword = lib.mkIf any true;
  };

  # --- home-manager side --------------------------------------------------
  mkHomeUser = {
    username,
    hostName,
  }: let
    meta = usersMeta.${username};
    home = assert lib.assertMsg (meta ? home)
    "usersMeta.${username} has no `home` block, but host '${hostName}' lists it in homeUsers";
      meta.home;
    override = home.hostOverrides.${hostName} or {};
    profile = override.profile or home.defaultProfile;
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
    programs.git = {
      enable = true;
      settings.user = {
        name = home.gitName;
        email = home.gitEmail;
      };
    };
  };

  mkHomeUsersForHost = hostName:
    lib.genAttrs (getHost "mkHomeUsersForHost" hostName).homeUsers
    (username:
      assert lib.assertMsg (usersMeta ? ${username})
      "mkHomeUsersForHost: no usersMeta entry for '${username}' (host '${hostName}')";
        mkHomeUser {inherit username hostName;});
in {
  flake.lib = {
    inherit
      mkSystemUser
      mkSystemUsersForHost
      mkSystemGroupsForHost
      mkSystemPolicyForHost
      mkHomeUser
      mkHomeUsersForHost
      ;
  };
}
