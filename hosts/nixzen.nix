{self, ...}: {
  flake.nixosConfigurations.nixzen = self.lib.mkHost {
    name = "nixzen";
    modules = [
      # Hardware
      self.nixosModules.hardw--zb15g2-k1
      # Host config
      self.nixosModules.hosts--nixzen
      self.nixosModules.hosts--profl--base
      self.nixosModules.hosts--profl--desktop
      # Services
    ];
  };
  flake.nixosModules.hosts--nixzen = {pkgs, ...}: {
    ## Graphical Shells ("none" "gnome" "plasma6")
    gShells.DE = "plasma6";

    ## DEVELOPMENT
    ## EDUCATION
    ## GAMING PACKAGES
    ## PRODUCTIVITY
    ## MEDIA PACKAGES
    ## VIRTUALIZATIONS

    ## SELF-HOSTED SERVICES

    # Define your Flatpak packages here
    flatpakPackages = [
    ];

    ## List packages installed in system profile. To search, run:
    ## $ nix search wget
    environment.systemPackages = with pkgs; [
    ];

    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    system.stateVersion = "24.11";
  };
}
