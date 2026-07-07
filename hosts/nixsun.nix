{self, ...}: {
  flake.nixosConfigurations.nixsun = self.lib.mkHost {
    name = "nixsun";
    modules = [
      # Hardware
      self.nixosModules.hardw--zb17g1-k4
      # Host config
      self.nixosModules.hosts--nixsun
      self.nixosModules.hosts--profl--base
      self.nixosModules.hosts--profl--desktop
      # Services
    ];
  };
  flake.nixosModules.hosts--nixsun = {
    config,
    pkgs,
    ...
  }: {
    ## Graphical Shells ("none" "gnome" "plasma6")
    gShells.DE = "plasma6";

    ## DEVELOPMENT
    blender.enable = true; #3D Creation/Animation/Publishing System
    godot.enable = true; #Free and Open Source 2D and 3D game engine
    ## EDUCATION
    ## GAMING PACKAGES
    steam.enable = true; #Video game digital distribution service and storefront from Valve
    ## PRODUCTIVITY
    libreoffice.enable = true; #Comprehensive, professional-quality productivity suite
    ## MEDIA PACKAGES
    obs.enable = true; #Free and open source software for video recording and live streaming
    ## VIRTUALIZATIONS
    quickemu.enable = true; #Quickly create and run optimised Windows, macOS and Linux virtual machines

    ## SELF-HOSTED SERVICES

    # Define your Flatpak packages here
    flatpakPackages = [
      #"com.discordapp.Discord" # Discord Talk, play, hang out
      "io.github.mhogomchungu.media-downloader" #A GUI to yt-dlp, gallery-dl and others
    ];

    ## List packages installed in system profile. To search, run:
    ## $ nix search wget
    environment.systemPackages = with pkgs; [
      python3 #High-level dynamically-typed programming language
    ];

    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    system.stateVersion = "24.11";
  };
}
