# This is your system's configuration file. Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{pkgs, ...}: {
  services.ignoreLid = {
    enable = true;
    # Optional:
    disableSleepTargets = true;
  };

  ## Enable CUPS to print documents.
  services.printing.enable = true;

  ## Enable automatic login for the user.
  services.displayManager.autoLogin.user = "temhr";

  ## Graphical Shells ("none" "gnome" "plasma6")
  gShells.DE = "plasma6";

  ## Development
  blender.enable = true; #3D Creation/Animation/Publishing System
  #godot.enable = true;    #Free and Open Source 2D and 3D game engine
  #vscodium.enable = true; #VS Code without MS branding/telemetry/licensing

  ## Education
  #anki.enable = true;  #Spaced repetition flashcard program

  ## Gaming Packages
  #steam.enable = true;  #Video game digital distribution service and storefront from Valve

  ## Productivity
  #calibre.enable = true;  #Comprehensive e-book software
  #libreoffice.enable = true;  #Comprehensive, professional-quality productivity suite
  logseq.enable = true; #Privacy-first, open-source platform for knowledge management and collaboration

  ## Media Packages
  #obs.enable = true;  #Free and open source software for video recording and live streaming
  #spotify.enable = true;  #Play music from the Spotify music service
  vlc.enable = true; #Cross-platform media player and streaming server

  ## Virtualizations
  #bottles.enable = true;    #Easy-to-use wineprefix manager
  #distrobox.enable = true;    #Wrapper around podman or docker to create and start containers
  incus.enable = true; #Powerful system container and virtual machine manager
  #podman.enable = true;    #A program for managing pods, containers and container images
  quickemu.enable = true; #Quickly create and run optimised Windows, macOS and Linux virtual machines
  #virt-manager.enable = true;    #Desktop user interface for managing virtual machines
  #wine.enable = true;    #Open Source implementation of the Windows API on top of X, OpenGL, and Unix

  ## Self-hosted apps and services
  services.homepage-custom = {
    enable = true;
    port = 3000;
    bindIP = "0.0.0.0";
    openFirewall = true;
    dataDir = "/data/homepage";
  };

  services.wikijs-custom = {
    enable = true;
    port = 3001;
    bindIP = "0.0.0.0";
    dataDir = "/data/wiki-js";
    openFirewall = true;
  };

  services.bookstack-custom = {
    enable = false;
    port = 3002;
    bindIP = "0.0.0.0";
    openFirewall = true;
    dataDir = "/data/bookstack";
  };

  services.homeassistant-custom = {
    enable = false;
    port = 8123;
    bindIP = "0.0.0.0";
    openFirewall = true;
    dataDir = "/data/homeassistant";
  };

  services.nodered-service = {
    enable = false;
    port = 1880;
    bindIP = "0.0.0.0";
    openFirewall = true;
    dataDir = "/data/node-red";
  };

  services.zola-custom = {
    enable = true;
    port = 3003;
    siteDir = "/data/www/myblog";
    bindIP = "0.0.0.0";
    openFirewall = true;
  };

  services.glance-custom = {
    enable = true;
    port = 3004;
    bindIP = "0.0.0.0";
    openFirewall = true;
    dataDir = "/data/glance";
  };

  services.ollama-cpu = {
    enable = true;
    ollamaPort = 11434;
    webuiPort = 3006;
    ollamaBindIP = "0.0.0.0";
    webuiBindIP = "0.0.0.0";
    ollamaDataDir = "/data/ollama";
    webuiDataDir = "/data/open-webui";
    # Pre-download models
    models = ["llama2" "mistral" "codellama"];
    openFirewall = true;
  };

  services.grafana-custom.enable = false;
  services.loki-custom.enable = false;
  services.prometheus-custom.enable = false;

  services.syncthing-custom = {
    enable = true;
    user = "temhr";
    group = "users";
    guiPort = 8384;
    guiAddress = "0.0.0.0";
    configDir = "/home/temhr/.config/syncthing";
    openFirewall = true;
    devices = {
      "nixzen" = {
        id = "ZBEUAV6-DMJ4XD5-JYHK54G-U67C76K-V43FXHB-TWNAKA4-MQY7VSM-45LNDQH";
        addresses = ["dynamic"];
        introducer = false;
      };
    };
    folders = {
      "mirror" = {
        path = "/mirror";
        id = "mirror";
        label = "mirror";
        devices = ["nixzen"];
        type = "sendreceive";
      };
    };
  };

  # Define your Flatpak packages here
  flatpakPackages = [
    #"com.usebottles.bottles"
  ];

  ## List packages installed in system profile. To search, run:
  ## $ nix search wget
  environment.systemPackages = with pkgs; [
  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.11";
}
