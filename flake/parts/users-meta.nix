{self, ...}: {
  flake.lib.usersMeta = {
    temhr = {
      gitName = "Temhr";
      gitEmail = "9110264+Temhr@users.noreply.github.com";
      defaultProfile = "desktop";
      hostOverrides = {
        nixnas1 = {profile = "minimal";};
        nixnas2 = {profile = "minimal";};
        nixace = {extraModules = [self.homeModules.temhr-nixace-extra];};
        nixtop = {extraModules = [self.homeModules.temhr-nixtop-extra];};
        nixvat = {extraModules = [self.homeModules.temhr-nixvat-extra];};
        nixsun = {extraModules = [self.homeModules.temhr-nixsun-extra];};
        nixzen = {extraModules = [self.homeModules.temhr-nixzen-extra];};
      };

      # NixOS account facts, independent of home-manager.
      isNormalUser = true;
      sshAuthorizedKeys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKITqIX76nKk6GvwM//USjaBD+YruF7YiTJxMNXUXVu2 temhr"];
      extraGroups = ["root" "wheel" "networkmanager" "adbusers" "kvm" "video" "render"];
      initialPassword = null;
    };

    guest = {
      isNormalUser = true;
      sshAuthorizedKeys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKITqIX76nKk6GvwM//USjaBD+YruF7YiTJxMNXUXVu2 guest"];
      extraGroups = [];
      initialPassword = "";
    };
    # rhmet = { gitName = "Rhmet"; gitEmail = "rhmet@example.com"; defaultProfile = "desktop"; hostOverrides = {}; };
  };
}
