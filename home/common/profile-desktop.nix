{
  self,
  lib,
  ...
}: {
  flake.homeModules.home--profl--desktop = {...}: {
    imports = [
      self.homeModules.home--apps--browsers
      self.homeModules.home--apps--ephemeral-apps
      self.homeModules.home--apps--terminal-emulators
      self.homeModules.home--apps--virtualization
    ];
    brave.enable = lib.mkDefault true;
    chrome.enable = lib.mkDefault true;
    zen.enable = lib.mkDefault true;
    ghostty.enable = lib.mkDefault true;
  };
}
