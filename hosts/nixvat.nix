{self, ...}: {
  flake.nixosConfigurations.nixvat = self.lib.mkHost {
    modules = [
      self.nixosModules.hosts--nixvat
      self.nixosModules.hosts--c-global
      self.nixosModules.hosts--c-optional--development
      self.nixosModules.hosts--c-optional--education
      self.nixosModules.hosts--c-optional--games
      self.nixosModules.hosts--c-optional--media
      self.nixosModules.hosts--c-optional--productivity
      self.nixosModules.hosts--c-optional--virtualizations
      self.nixosModules.hardw--zb17g1-k3
      self.nixosModules.systm--cachix
      self.nixosModules.systm--gui-shells
      self.nixosModules.systm--ignore-lid
      self.nixosModules.servc--bookstack-nixlab
      self.nixosModules.secrets--bookstack
      self.nixosModules.servc--comfyui-p5000
      self.nixosModules.servc--comfyui-extensions
      self.nixosModules.servc--comfyui-models
      self.nixosModules.servc--homepage-nixlab
      self.nixosModules.servc--ollama-cpu
      self.nixosModules.servc--glance-nixlab
      self.nixosModules.servc--gotosocial-nixlab
      self.nixosModules.servc--home-assistant-nixlab
      self.nixosModules.servc--node-red-nixlab
      self.nixosModules.servc--syncthing-nixlab
      self.nixosModules.servc--wiki-js-nixlab
      self.nixosModules.servc--zola-nixlab
      self.nixosModules.servc--monitoring-nixlab
      self.nixosModules.servc--grafana-nixlab
      self.nixosModules.secrets--grafana
      self.nixosModules.servc--loki-nixlab
      self.nixosModules.servc--prometheus-nixlab
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
    networking.hostName = "nixvat";

    ## Shared system-wide user option
    nixlab.mainUser = "temhr";
    ## Enable automatic login for the user.
    services.displayManager.autoLogin.user = config.nixlab.mainUser;

    ## Graphical Shells ("none" "gnome" "plasma6")
    gShells.DE = "plasma6";

    services.ignoreLid = {
      enable = true;
      # Optional:
      disableSleepTargets = true;
    };

    ## Enable CUPS to print documents.
    services.printing.enable = true;

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
    logseq.enable = true; #Privacy-first, open-source platform for knowledge management and collaboration
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
    services.homepage-nixlab = {
      enable = true;
      port = 3000;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/homepage";
    };
    services.wikijs-custom = {
      enable = true;
      port = 3001;
      listenAddress = "0.0.0.0";
      dataDir = "/data/wiki-js";
      openFirewall = true;
    };
    services.bookstack-nixlab = {
      enable = false;
      port = 3002;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/bookstack";
    };
    services.homeassistant-custom = {
      enable = false;
      port = 8123;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/homeassistant";
    };
    services.nodered-service = {
      enable = false;
      port = 1880;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/node-red";
    };
    services.zola-nixlab = {
      enable = true;
      port = 3003;
      siteDir = "/data/www/myblog";
      listenAddress = "0.0.0.0";
      openFirewall = true;
    };
    services.glance-nixlab = {
      enable = true;
      port = 3004;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/glance";
    };
    services.ollama-cpu = {
      enable = true;
      ollamaPort = 11434;
      webuiPort = 3006;
      ollamaListenAddress = "0.0.0.0";
      webuiListenAddress = "0.0.0.0";
      ollamaDataDir = "/data/ollama";
      webuiDataDir = "/data/open-webui";
      # Pre-download models
      models = ["llama2" "mistral" "codellama"];
      openFirewall = true;
    };
    services.nixlab-monitoring = {
      enable = true;
      dataDir = "/data";
      openFirewall = true;
      ports.grafana = 3101;
      ports.loki = 3100;
      ports.prometheus = 9090;
      loki.maintenance.enable = true;
      prometheus.maintenance.enable = true;
      prometheus.maintenance.exporters.systemd = true;
      prometheus.maintenance.exporters.smartctl.enable = true;
    };
    services.syncthing-nixlab = {
      enable = true;
      user = "${config.nixlab.mainUser}";
      group = "users";
      guiPort = 8384;
      guiAddress = "0.0.0.0";
      configDir = "/home/${config.nixlab.mainUser}/.config/syncthing";
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
  };
}
