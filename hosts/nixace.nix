{self, ...}: {
  flake.nixosModules.hosts--nixace = {
    config,
    pkgs,
    ...
  }: {
    networking.hostName = "nixace";

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
    godot.enable = true; #Free and Open Source 2D and 3D game engine
    vscodium.enable = true; #VS Code without MS branding/telemetry/licensing
    ## EDUCATION
    anki.enable = true; #Spaced repetition flashcard program
    ## GAMING PACKAGES
    steam.enable = true; #Video game digital distribution service and storefront from Valve
    ## PRODUCTIVITY
    #calibre.enable = true;  #Comprehensive e-book software
    libreoffice.enable = true; #Comprehensive, professional-quality productivity suite
    logseq.enable = true; #Privacy-first, open-source platform for knowledge management and collaboration
    ## MEDIA PACKAGES
    obs.enable = true; #Free and open source software for video recording and live streaming
    spotify.enable = true; #Play music from the Spotify music service
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
    #sudo systemctl restart ollama-models #Download Ollama Models
    #sudo journalctl -u ollama-models -f  #journal
    ##Remove models
    #systemctl cat ollama | grep ExecStart
    #sudo -u ollama OLLAMA_MODELS=/data/ollama/models /nix/store/h10qpb3ac91irs946dzissanbs2klz4a-ollama-cuda-p5000-0.12.11/bin/ollama rm [model]
    services.ollama-p5000 = {
      enable = true;
      # Network configuration
      ollamaPort = 11434;
      webuiPort = 3007;
      ollamaListenAddress = "0.0.0.0"; # Listen on all interfaces
      webuiListenAddress = "0.0.0.0";
      # Data directories
      ollamaDataDir = "/data/ollama";
      webuiDataDir = "/data/open-webui";
      # GPU configuration
      gpuDevice = 0; # First GPU
      gpuLayers = -1; # Offload all layers to GPU (-1 = auto)
      # Pre-download models
      models = ["gpt-oss:20b" "translategemma:27b" "glm-4.7-flash:q4_K_M" "qwen3-coder-next:q4_K_M" "qwen3.5:35b"];
      openFirewall = true;
    };
    services.comfyui-p5000 = {
      enable = true;
      # Network configuration
      port = 8188;
      listenAddress = "0.0.0.0"; # Listen on all interfaces
      # Data directory (models, outputs, inputs)
      dataDir = "/data/comfyui";
      # GPU configuration
      gpuDevice = 0; # First GPU
      openFirewall = true;
    };
    services.comfyui-extensions = {
      enable = true;
      # Recommended: Install ComfyUI-Manager (enabled by default)
      enableManager = true;
      # Optional: Enable ControlNet support
      enableControlNet = true;
      # Optional: Enable common image processing nodes
      enableImageProcessing = true;
      # Optional: Enable video processing nodes
      enableVideoProcessing = true;
      # Optional: Install custom nodes from git repos
      customNodes = [
        /*
        {
          name = "ComfyUI-Impact-Pack";
          url = "https://github.com/ltdrdata/ComfyUI-Impact-Pack";
          rev = "main";
        }
        {
          name = "ComfyUI-AnimateDiff-Evolved";
          url = "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved";
          rev = "main";
        }
        */
      ];
    };
    services.comfyui-models = {
      enable = true;
      # Download Stable Diffusion 1.5 (good for P5000 with 16GB VRAM)
      downloadSD15 = true;
      # Download SDXL (requires more VRAM, might need --lowvram flag)
      downloadSDXL = true;
      # Download recommended VAE models
      downloadVAE = true;
      # Download upscale models
      downloadUpscalers = true;
      # Download custom models
      customModels = [
        /*
        {
          name = "my-custom-model.safetensors";
          url = "https://civitai.com/api/download/models/12345";
          type = "checkpoint";
        }
        */
      ];
    };
    networking.firewall.extraInputRules = ''
      ip saddr 10.88.0.0/16 tcp dport 3306 accept
    '';
    services.bookstack-nixlab = {
      enable = true;
      appURL = "http://192.168.0.200:6875";
      dataDir = "/data/bookstack";
      dataMountUnit = "data.mount";
      dbRootPasswordFile = config.sops.secrets.MYSQL_ROOT_PASSWORD.path;
      dbPasswordFile = config.sops.secrets.DB_PASS.path;
      appKeyFile = config.sops.secrets.APP_KEY.path;
    };
    # Dashboard paths removed entirely.
    # Module supplies its own defaults.
    services.grafana-nixlab = {
      enable = false;
      port = 3101;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/grafana";
      # dashboards uses module defaults
    };
    services.loki-nixlab.enable = false;
    services.prometheus-nixlab.enable = false;

    # Define your Flatpak packages here
    flatpakPackages = [
      "com.usebottles.bottles"
    ];

    ## List packages installed in system profile. To search, run:
    ## $ nix search wget
    environment.systemPackages = with pkgs; [
    ];

    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    system.stateVersion = "24.11";
  };

  flake.nixosConfigurations.nixace = self.lib.mkHost {
    modules = [
      self.nixosModules.hw--c-global
      self.nixosModules.hw--c-optional--driver-nvidia
      self.nixosModules.hw--zb17g4-p5
      self.nixosModules.hosts--nixace
      self.nixosModules.hosts--c-global
      self.nixosModules.hosts--c-optional--development
      self.nixosModules.hosts--c-optional--education
      self.nixosModules.hosts--c-optional--games
      self.nixosModules.hosts--c-optional--media
      self.nixosModules.hosts--c-optional--productivity
      self.nixosModules.hosts--c-optional--virtualizations
      self.nixosModules.sys--cachix
      self.nixosModules.sys--gui-shells
      self.nixosModules.sys--ignore-lid
      self.nixosModules.sys--monitoring
      self.nixosModules.svc--bookstack-nixlab
      self.nixosModules.secrets--bookstack
      self.nixosModules.svc--comfyui-p5000
      self.nixosModules.svc--comfyui-extensions
      self.nixosModules.svc--comfyui-models
      self.nixosModules.svc--grafana-nixlab
      self.nixosModules.secrets--grafana
      self.nixosModules.svc--loki-nixlab
      self.nixosModules.svc--ollama-p5000
      self.nixosModules.svc--prometheus-nixlab
    ];
  };
}
