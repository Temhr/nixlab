{self, ...}: {
  flake.nixosConfigurations.nixsun = self.lib.mkHost {
    name = "nixsun";
    modules = [
      # Hardware
      self.nixosModules.hardw--zb17g1-k4
      # Host config
      self.nixosModules.hosts--nixsun
      self.nixosModules.hosts--c-global
      # Home manager
      # Services
    ];
  };
  flake.nixosModules.hosts--nixsun = {
    config,
    pkgs,
    ...
  }: {
    ## Shared system-wide user option
    nixlab.mainUser = "temhr";
    ## Enable automatic login for the user.
    services.displayManager.autoLogin.user = config.nixlab.mainUser;

    ## Graphical Shells ("none" "gnome" "plasma6")
    gShells.DE = "plasma6";

    ## Enable CUPS to print documents.
    services.printing.enable = true;

    ## DEVELOPMENT
    blender.enable = true; #3D Creation/Animation/Publishing System
    godot.enable = true; #Free and Open Source 2D and 3D game engine
    #vscodium.enable = true; #VS Code without MS branding/telemetry/licensing
    ## EDUCATION
    #anki.enable = true;  #Spaced repetition flashcard program
    ## GAMING PACKAGES
    steam.enable = true; #Video game digital distribution service and storefront from Valve
    ## PRODUCTIVITY
    #calibre.enable = true;  #Comprehensive e-book software
    libreoffice.enable = true; #Comprehensive, professional-quality productivity suite
    #logseq.enable = true;  #Privacy-first, open-source platform for knowledge management and collaboration
    ## MEDIA PACKAGES
    #obs.enable = true;  #Free and open source software for video recording and live streaming
    #spotify.enable = true;  #Play music from the Spotify music service
    #vlc.enable = true;  #Cross-platform media player and streaming server
    ## VIRTUALIZATIONS
    #bottles.enable = true;    #Easy-to-use wineprefix manager
    #distrobox.enable = true;    #Wrapper around podman or docker to create and start containers
    #incus.enable = true;   #Powerful system container and virtual machine manager
    #podman.enable = true;    #A program for managing pods, containers and container images
    quickemu.enable = true; #Quickly create and run optimised Windows, macOS and Linux virtual machines
    #virt-manager.enable = true;    #Desktop user interface for managing virtual machines
    #wine.enable = true;    #Open Source implementation of the Windows API on top of X, OpenGL, and Unix
    #virtualisation.waydroid.enable = true; #requires "$sudo waydroid init" with "-s GAPPS -f" flag option

    ## SELF-HOSTED SERVICES

    # Define your Flatpak packages here
    flatpakPackages = [
      #"com.usebottles.bottles"
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
