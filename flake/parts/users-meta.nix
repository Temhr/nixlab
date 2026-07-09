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
    };
    # guest = { gitName = "Guest"; gitEmail = "guest@localhost"; defaultProfile = "minimal"; hostOverrides = {}; };
    # rhmet = { gitName = "Rhmet"; gitEmail = "rhmet@example.com"; defaultProfile = "desktop"; hostOverrides = {}; };
  };
}
