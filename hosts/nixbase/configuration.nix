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
    ../../modules/nixos

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    ../globals

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
    ./nvidia.nix
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

    ## Garbage collection to maintain low disk usage
    gc = {
      automatic = true;
      dates = "*-*-* 02:00:00";
      options = "--delete-older-than 10d";
    };
    ## Optimize storage (only for incoming/new files)
    settings.auto-optimise-store = true;
  };

  ## Bootloader - systemd-boot
  boot.loader.systemd-boot.enable = true;
  ## Limit the number of generations to present
  boot.loader.systemd-boot.configurationLimit = 10;

  # TODO: Set your hostname
  networking.hostName = "nixbase";

  ## Enable networking
  networking.networkmanager.enable = true;

  ## Graphical Shells
  #gnome.enable = true; #Gnome - Desktop Environment
  plasma.enable = true; #KDE - Desktop Environment
  #sway.enable = true;  #Wayland Compositor NEEDS WORK

  ## Terminal Emulators
  #alacritty.enable = true;  #Cross-platform, GPU-accelerated terminal emulator
  ghostty.enable = true;  #fast, feature-rich, and cross-platform terminal emulator that uses platform-native UI and GPU acceleration
  #kitty.enable = true;  #Modern, hackable, featureful, OpenGL based terminal emulator
  #konsole.enable = true;  #Terminal emulator by KDE

  ## Enable CUPS to print documents.
  services.printing.enable = true;

  ## Enable Syncthing (only for this host)
  #syncace.enable = true;
  syncbase.enable = true;
  #synctop.enable = true;

  ## Gaming Packages
  #openSourceGames.enable = true;
  #steam.enable = true;  #Video game digital distribution service and storefront from Valve

  ## Productivity
  calibre.enable = true;  #Comprehensive e-book software
  #libreoffice.enable = true;  #Comprehensive, professional-quality productivity suite

  ## Media Packages
  #audacity.enable = true;  #Sound editor with graphical UI
  #kdenlive.enable = true;  #Free and open source video editor, based on MLT Framework and KDE Frameworks
  #obs.enable = true;  #Free and open source software for video recording and live streaming
  #spotify.enable = true;  #Play music from the Spotify music service
  vlc.enable = true;  #Cross-platform media player and streaming server

  ## Virtualizations
  distrobox.enable = true;    #Wrapper around podman or docker to create and start containers
  incus.enable = true;   #Powerful system container and virtual machine manager
  podman.enable = true;    #A program for managing pods, containers and container images
  quickemu.enable = true;    #Quickly create and run optimised Windows, macOS and Linux virtual machines
  virt-manager.enable = true;    #Desktop user interface for managing virtual machines

  ## List packages installed in system profile. To search, run:
  ## $ nix search wget
  environment.systemPackages = with pkgs; [

    ## Dev Tools
    unstable.blender  #3D Creation/Animation/Publishing System

    ## Godot Dev Tools
    gcc14  #GNU Compiler Collection, version 14.1.0 (wrapper script)
    pkg-config  #Tool that allows packages to find out information about other packages (wrapper script)
    scons  #Improved, cross-platform substitute for Make
    python3Full  #High-level dynamically-typed programming language

    ## Communication
    discord  #All-in-one cross-platform voice and text chat for gamers

  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.11";
}
