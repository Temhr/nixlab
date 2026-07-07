{self, ...}: {
  flake.nixosConfigurations.nixvat = self.lib.mkHost {
    name = "nixvat";
    modules = [
      # Hardware
      self.nixosModules.hardw--zb17g1-k3
      # Host config
      self.nixosModules.hosts--nixvat
      self.nixosModules.hosts--profl--base
      self.nixosModules.hosts--profl--desktop
      # Services
      self.nixosModules.nsops--glance
      self.nixosModules.nsops--ollama
      self.nixosModules.nsops--wiki-js
      self.nixosModules.servc--zola-nixlab
    ];
  };
  flake.nixosModules.hosts--nixvat = {
    config,
    inputs,
    pkgs,
    ...
  }: {
    imports = [
      "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
    ];
    ## Enable automatic login for the user.
    services.displayManager.autoLogin.user = config.nixlab.mainUser;

    ## Graphical Shells ("none" "gnome" "plasma6")
    gShells.DE = "plasma6";

    ## DEVELOPMENT
    blender.enable = true; #3D Creation/Animation/Publishing System
    #godot.enable = true;    #Free and Open Source 2D and 3D game engine
    #vscodium.enable = true; #VS Code without MS branding/telemetry/licensing
    ## EDUCATION
    #anki.enable = true;  #Spaced repetition flashcard program
    ## GAMING PACKAGES
    #steam.enable = true;  #Video game digital distribution service and storefront from Valve
    ## PRODUCTIVITY
    #calibre.enable = true;  #Comprehensive e-book software
    #libreoffice.enable = true;  #Comprehensive, professional-quality productivity suite
    #logseq.enable = true; #Privacy-first, open-source platform for knowledge management and collaboration
    ## MEDIA PACKAGES
    #obs.enable = true;  #Free and open source software for video recording and live streaming
    #spotify.enable = true;  #Play music from the Spotify music service
    vlc.enable = true; #Cross-platform media player and streaming server
    ## VIRTUALIZATIONS
    #bottles.enable = true;    #Easy-to-use wineprefix manager
    #distrobox.enable = true;    #Wrapper around podman or docker to create and start containers
    incus.enable = true; #Powerful system container and virtual machine manager
    #podman.enable = true;    #A program for managing pods, containers and container images
    quickemu.enable = true; #Quickly create and run optimised Windows, macOS and Linux virtual machines
    #virt-manager.enable = true;    #Desktop user interface for managing virtual machines
    #wine.enable = true;    #Open Source implementation of the Windows API on top of X, OpenGL, and Unix
    #virtualisation.waydroid.enable = true; #requires "$sudo waydroid init" with "-s GAPPS -f" flag option

    ## SELF-HOSTED SERVICES
    services.glance-nixlab = {
      enable = true;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/glance";
    };
    services.wikijs-custom = {
      enable = true;
      listenAddress = "0.0.0.0";
      dataDir = "/data/wiki-js";
      openFirewall = true;
    };
    services.zola-nixlab = {
      enable = true;
      siteDir = "/data/www/myblog";
      listenAddress = "0.0.0.0";
      openFirewall = true;
      package = pkgs.unstable.zola;
      configToml = {
        title = "My Blog";
        compile_sass = true;
        build_search_index = true;
        markdown = {};
      };
      extraUsers = [config.nixlab.mainUser];
    };
    services.ollama-stack = {
      enable = true;
      acceleration = "cpu";
      extraUsers = [config.nixlab.mainUser];
      ollamaListenAddress = "0.0.0.0";
      webuiListenAddress = "0.0.0.0";
      # Data directories
      ollamaDataDir = "/data/ollama";
      webuiDataDir = "/data/open-webui";
      # Pre-download models
      models = ["qwen3.5:35b" "gemma4:31b" "qwen3.6:35b" ""];
      openFirewall = true;
    };

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
