{self, ...}: {
  flake.lib.usersMeta = {
    temhr = {
      # home-manager which further descibes select user accounts that NixOS has already initialised & defined in host-meta
      gitName = "Temhr";
      gitEmail = "9110264+Temhr@users.noreply.github.com";
      defaultProfile = "desktop";
      hostOverrides = {
        nixnas1 = {profile = "minimal";};
        nixnas2 = {profile = "minimal";};
        nixace = {extraModules = [self.homeModules.temhr-nixace-extra];};
      };

      # NixOS account facts, independent of home-manager.
      isNormalUser = true;
      sshAuthorizedKeys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKITqIX76nKk6GvwM//USjaBD+YruF7YiTJxMNXUXVu2 temhr"];
      extraGroups = ["root" "wheel" "networkmanager" "adbusers" "kvm" "video" "render"];
      initialPassword = null;
    };

    guest = {
      # NixOS account facts, independent of home-manager.
      isNormalUser = true;
      sshAuthorizedKeys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKITqIX76nKk6GvwM//USjaBD+YruF7YiTJxMNXUXVu2 guest"];
      extraGroups = [];
      initialPassword = "";
    };
    # rhmet = { gitName = "Rhmet"; gitEmail = "rhmet@example.com"; defaultProfile = "desktop"; hostOverrides = {}; };
  };
}
