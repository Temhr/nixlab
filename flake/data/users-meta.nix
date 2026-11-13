{self, ...}: {
  flake.lib.usersMeta = {
    temhr = {
      # NixOS account facts. Passed verbatim to users.users.temhr,
      # so any NixOS user option is valid here.
      account = {
        isNormalUser = true;
        group = "temhr";
        homeMode = "770";
        extraGroups = ["wheel" "networkmanager" "adbusers" "kvm" "video" "render" "users" "guest"];
        openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKITqIX76nKk6GvwM//USjaBD+YruF7YiTJxMNXUXVu2 temhr"];
      };

      # Optional extra attrs for users.groups.<account.group>.
      groupConfig = {};

      # home-manager layer, further describing the account NixOS already defined.
      home = {
        gitName = "Temhr";
        gitEmail = "9110264+Temhr@users.noreply.github.com";
        defaultProfile = "desktop";
        hostOverrides = {
          nixnas1 = {profile = "minimal";};
          nixnas2 = {profile = "minimal";};
          nixace = {extraModules = [self.homeModules.temhr-nixace-extra];};
          nixsun = {extraModules = [self.homeModules.temhr-nixsun-extra];};
          nixtop = {extraModules = [self.homeModules.temhr-nixtop-extra];};
          nixvat = {extraModules = [self.homeModules.temhr-nixvat-extra];};
          nixzen = {extraModules = [self.homeModules.temhr-nixzen-extra];};
        };
      };
    };

    # Shared guest: no password, no SSH, no privileges, no home-manager.
    guest = {
      account = {
        isNormalUser = true;
        description = "Guest";
        uid = 1100; # pinned so the optional tmpfs home can reference it
        group = "guest";
        homeMode = "775"; # guest: full, group `guest`: read-only, others: read-only
        extraGroups = []; # no wheel, no networkmanager, nothing
        initialPassword = ""; # empty password, local login only
      };
      groupConfig.gid = 1100;
    };

    # rhmet = {
    #   account = {isNormalUser = true; group = "rhmet";};
    #   home = {gitName = "Rhmet"; gitEmail = "rhmet@example.com"; defaultProfile = "desktop"; hostOverrides = {};};
    # };
  };
}
