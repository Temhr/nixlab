{self, ...}: {
  flake.homeModules.home--c-global = {...}: {
    imports = [
      self.homeModules.common-global--config-fastfetch
      self.homeModules.common-global--config-folders
      self.homeModules.common-global--config-git
      self.homeModules.common-global--config-ssh
      self.homeModules.common-global--ephemeral-apps
      self.homeModules.common-global--system
      self.homeModules.common-global--utilities

      self.homeModules.common-optional--bash-files-symlink
      self.homeModules.common-optional--browsers
      self.homeModules.common-optional--terminal-emulators
    ];
  };
}
