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
      self.nixosModules.nsops--hermes
      self.nixosModules.nsops--matrix
      self.nixosModules.nsops--ollama
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
    services.matrix-nixlab = {
      enable = true;
      #initUsers.enable = false;
    };
    services.nixlab-hermes = {
      enable = true;
      model = {
        baseUrl = "http://127.0.0.1:11434/v1";
        default = "gemma4:e4b";
      };
      dashboard = {
        enable = true;
        listenAddress = "0.0.0.0";
        openFirewall = true;
        allowUnauthenticatedLan = true;
      };
      # Phase 2 — flip this on once Ollama is confirmed working, after adding
      # MATRIX_USER_ID / MATRIX_PASSWORD to sops/hermes.env (see guide):
      # matrix.enable = true;
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
      models = ["gemma4:e4b"];
      openFirewall = true;
    };

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
