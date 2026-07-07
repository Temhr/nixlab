{self, ...}: {
  flake.nixosModules.hosts--profl--desktop = {
    config,
    lib,
    ...
  }: {
    imports = [
      self.nixosModules.hosts--apps--development
      self.nixosModules.hosts--apps--education
      self.nixosModules.hosts--apps--games
      self.nixosModules.hosts--apps--media
      self.nixosModules.hosts--apps--productivity
      self.nixosModules.hosts--apps--virtualizations

      self.nixosModules.hosts--deskt--cache-tmpfs
      self.nixosModules.hosts--deskt--firefox
      self.nixosModules.hosts--deskt--flatpak
      self.nixosModules.hosts--deskt--gui-shells
      self.nixosModules.hosts--deskt--ignore-lid
    ];

    ## Automatic login for this user
    services.displayManager.autoLogin.user = config.nixlab.mainUser;

    # Define your Flatpak packages here
    flatpakPackages = [
      "net.davidotek.pupgui2" # ProtonUp-Qt Install Wine- and Proton-based compatibility tools
    ];
  };
}
