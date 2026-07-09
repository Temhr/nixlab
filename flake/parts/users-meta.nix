{...}: {
  flake.lib.usersMeta = {
    temhr = {
      gitName = "Temhr";
      gitEmail = "9110264+Temhr@users.noreply.github.com";
      defaultProfile = "desktop";
      hostOverrides = {
        nixnas1 = {profile = "minimal";};
        nixnas2 = {profile = "minimal";};
      };
    };
    # guest = { gitName = "Guest"; gitEmail = "guest@localhost"; defaultProfile = "minimal"; hostOverrides = {}; };
    # rhmet = { gitName = "Rhmet"; gitEmail = "rhmet@example.com"; defaultProfile = "desktop"; hostOverrides = {}; };
  };
}
