{self, ...}: {
  flake.nixosConfigurations.nixtop = self.lib.mkHost {
    name = "nixtop";
    modules = [
      # Hardware
      self.nixosModules.hardw--zb17g2-k5
      # Host config
      self.nixosModules.hosts--nixtop
      self.nixosModules.hosts--profl--base
      self.nixosModules.hosts--profl--desktop
      # Services
      self.nixosModules.servc--waydroid-nixlab
    ];
  };
  flake.nixosModules.hosts--nixtop = {
    config,
    pkgs,
    ...
  }: {
    ## Graphical Shells ("none" "gnome" "plasma6")
    gShells.DE = "plasma6";

    ## DEVELOPMENT
    blender.enable = true; #3D Creation/Animation/Publishing System
    godot.enable = true; #Free and Open Source 2D and 3D game engine
    vscodium.enable = true; #VS Code without MS branding/telemetry/licensing
    ## EDUCATION
    anki.enable = true; #Spaced repetition flashcard program
    ## GAMING PACKAGES
    steam.enable = true; #Video game digital distribution service and storefront from Valve
    ## PRODUCTIVITY
    libreoffice.enable = true; #Comprehensive, professional-quality productivity suite
    ## MEDIA PACKAGES
    obs.enable = true; #Free and open source software for video recording and live streaming
    spotify.enable = true; #Play music from the Spotify music service
    vlc.enable = true; #Cross-platform media player and streaming server
    ## VIRTUALIZATIONS
    quickemu.enable = true; #Quickly create and run optimised Windows, macOS and Linux virtual machines

    ## SELF-HOSTED SERVICES
    services.waydroid-nixlab = {
      enable = true;
      dataDir = "/data/waydroid";
      allowedUsers = ["${config.nixlab.mainUser}"];
      autoStart = false;
      enableGapps = true;
    };

    # Define your Flatpak packages here
    flatpakPackages = [
    ];

    ## List packages installed in system profile. To search, run:
    ## $ nix search wget
    environment.systemPackages = with pkgs; [
      qbittorrent # Featureful free software BitTorrent client
    ];

    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    system.stateVersion = "24.11";
  };
}
