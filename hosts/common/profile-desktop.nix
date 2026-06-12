{self, ...}: {
  flake.nixosModules.hosts--profl--desktop = {...}: {
    imports = [
      self.nixosModules.hosts--apps--development
      self.nixosModules.hosts--apps--education
      self.nixosModules.hosts--apps--games
      self.nixosModules.hosts--apps--media
      self.nixosModules.hosts--apps--productivity
      self.nixosModules.hosts--apps--virtualizations

      self.nixosModules.hosts--deskt--firefox
      self.nixosModules.hosts--deskt--flatpak
      self.nixosModules.hosts--deskt--gui-shells
      self.nixosModules.hosts--deskt--ignore-lid
    ];

    # Define your Flatpak packages here
    flatpakPackages = [
      "net.davidotek.pupgui2" # ProtonUp-Qt Install Wine- and Proton-based compatibility tools
    ];
  };
}
