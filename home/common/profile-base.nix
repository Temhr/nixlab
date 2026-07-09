{self, ...}: {
  flake.homeModules.home--profl--base = {...}: {
    imports = [
      self.homeModules.home--core--config-fastfetch
      self.homeModules.home--core--config-folders
      self.homeModules.home--core--config-git
      self.homeModules.home--core--config-ssh
      self.homeModules.home--core--ephemeral-apps
      self.homeModules.home--core--system
      self.homeModules.home--core--utilities
      self.homeModules.home--shell--bash
    ];
  };
}
