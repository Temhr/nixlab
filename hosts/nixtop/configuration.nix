# This is your system's configuration file. Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/nixos):
    # outputs.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
    ./nvidia.nix

    ../common/global/locale.nix
    ../common/global/users.nix
    ../common/global/utilities.nix

    ../common/optional/steam.nix
    ../common/optional/syncthing.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Opinionated: disable global registry
      flake-registry = "";
      # Workaround for https://github.com/NixOS/nix/issues/9574
      nix-path = config.nix.nixPath;
    };
    # Opinionated: disable channels
    channel.enable = false;

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

    ## Perform garbage collection daily to maintain low disk usage
    gc = {
      automatic = true;
      dates = "*-*-* 02:00:00";
      options = "--delete-older-than 10d";
    };
    ## Optimize storage for incoming new files
    settings.auto-optimise-store = true;
  };

  # FIXME: Add the rest of your current configuration

  ## Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  ## Limit the number of generations to keep
  boot.loader.systemd-boot.configurationLimit = 10;
  #boot.loader.grub.configurationLimit = 10;

  # TODO: Set your hostname
  networking.hostName = "nixtop";

  ## Enable networking
  networking.networkmanager.enable = true;
  ## Enable the X11 windowing system.
  services.xserver.enable = true;
  ## Enable Plasma6
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;


  ## Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  ## Enable CUPS to print documents.
  services.printing.enable = true;
  ## Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  ## Togglable Programs
  synctop.enable = true;
  steam.enable = true;

  ## Install firefox.
  programs.firefox = {
    enable = true;
  };

  ## List packages installed in system profile. To search, run:
  ## $ nix search wget
  environment.systemPackages = with pkgs; [

    kdePackages.partitionmanager  #Manage the disk devices, partitions and file systems on your computer

    ## Dev Tools
    unstable.blender  #3D Creation/Animation/Publishing System
    android-tools  #Android SDK platform tools
    gdb  #The GNU Project debugger
    gdbgui  #A browser-based frontend for GDB
    gnumake  #A tool to control the generation of non-source files from sources

    ## Godot Dev Tools
    gcc14  #GNU Compiler Collection, version 14.1.0 (wrapper script)
    pkg-config  #Tool that allows packages to find out information about other packages (wrapper script)
    scons  #Improved, cross-platform substitute for Make
    python3Full  #High-level dynamically-typed programming language

    ## Browsers
    brave  #Privacy-oriented browser for Desktop and Laptop computers
    microsoft-edge  #The web browser from Microsoft
    google-chrome  #Freeware web browser developed by Google
    #vivaldi  #A Browser for our Friends, powerful and personal

    ## Communication
    discord  #All-in-one cross-platform voice and text chat for gamers
    obs-studio  #Free and open source software for video recording and live streaming
    unstable.scrcpy  #Display and control Android devices over USB or TCP/IP
    ffmpeg  #A complete, cross-platform solution to record, convert and stream audio and video

    ## Games
    lutris  #Open Source gaming platform for GNU/Linux
    superTuxKart  #A Free 3D kart racing game

    ## Media
    audacity  #Sound editor with graphical UI
    kdePackages.kdenlive  #Free and open source video editor, based on MLT Framework and KDE Frameworks
    simplescreenrecorder  #A screen recorder for Linux
    spotify  #Play music from the Spotify music service
    vlc  #Cross-platform media player and streaming server

    ## Productivity
    calibre  #Comprehensive e-book software
    libreoffice-fresh  #Comprehensive, professional-quality productivity suite

    ## Virtualizations
    incus #Powerful system container and virtual machine manager
    distrobox  #Wrapper around podman or docker to create and start containers
    podman  #A program for managing pods, containers and container images
  ];

  # This setups a SSH server. Very important if you're setting up a headless system.
  # Feel free to remove if you don't need it.
  services.openssh = {
    enable = true;
    settings = {
      # Opinionated: forbid root login through SSH.
      PermitRootLogin = "no";
      # Opinionated: use keys only.
      # Remove if you want to SSH using passwords
      PasswordAuthentication = false;
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.11";
}
