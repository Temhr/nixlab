{self, ...}: {
  flake.nixosConfigurations.nixace = self.lib.mkHost {
    name = "nixace";
    modules = [
      self.nixosModules.hosts--nixace
      self.nixosModules.hosts--c-global
      self.nixosModules.hardw--zb17g4-p5
      self.nixosModules.servc--bookstack-nixlab
      self.nixosModules.secrets--bookstack
      self.nixosModules.servc--comfyui-p5000
      self.nixosModules.servc--comfyui-extensions
      self.nixosModules.servc--comfyui-models
      self.nixosModules.servc--ollama
      self.nixosModules.secrets--ollama
    ];
  };
  flake.nixosModules.hosts--nixace = {
    config,
    pkgs,
    hostMeta,
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
    services.ollama-stack = {
      enable = true;
      acceleration = "cuda-p5000";
      extraUsers = [config.nixlab.mainUser];
      ollamaListenAddress = "0.0.0.0";
      webuiListenAddress = "0.0.0.0";
      # Data directories
      ollamaDataDir = "/data/ollama";
      webuiDataDir = "/data/open-webui";
      # GPU configuration
      gpuDevice = 0; # First GPU
      gpuLayers = -1; # Offload all layers to GPU (-1 = auto)
      # Pre-download models
      models = ["qwen3-coder-next:q4_K_M" "qwen3.5:35b" "gemma4:31b" "qwen3.6:35b-a3b-coding-mxfp8"];
      openFirewall = true;
    };
    services.comfyui-p5000 = {
      enable = true;
      # Network configuration
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
      listenAddress = "0.0.0.0";
      appURL = "http://${hostMeta.address}:6875";
      dataDir = "/data/bookstack";
      dataMountUnit = "data.mount";
      openFirewall = true;
      dbRootPasswordFile = config.sops.secrets.MYSQL_ROOT_PASSWORD.path;
      dbPasswordFile = config.sops.secrets.DB_PASS.path;
      appKeyFile = config.sops.secrets.APP_KEY.path;
    };

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
}
