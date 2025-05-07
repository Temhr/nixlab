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
    ../common/core
    ../common/optional
    ../../cachix.nix
    ../../modules/nixos

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
      ./additional-drives.nix
      ./nvidia.nix
  ];

  # TODO: Set your hostname
  networking.hostName = "nixace";

  ## Enable networking
  networking.networkmanager.enable = true;

  ## Enable CUPS to print documents.
  services.printing.enable = true;

  ## Enable Syncthing ("hostname" or "none")
  syncthing.system = "none";

  ## Graphical Shells ("none" "gnome" "plasma6")
  gShells.DE = "plasma6";

  ## Education
  anki.enable = true;  #Spaced repetition flashcard program
  #google-earth.enable = true;  #World sphere viewer "not secure""

  ## Gaming Packages
  openSourceGames.enable = true;  #Open Source gaming platform for GNU/Linux
  steam.enable = true;  #Video game digital distribution service and storefront from Valve

  ## Communication
  discord.enable = true;  #All-in-one cross-platform voice and text chat for gamers

  ## Productivity
  calibre.enable = true;  #Comprehensive e-book software
  libreoffice.enable = true;  #Comprehensive, professional-quality productivity suite

  ## Media Packages
  audacity.enable = true;  #Sound editor with graphical UI
  kdenlive.enable = true;  #Free and open source video editor, based on MLT Framework and KDE Frameworks
  media-downloader.enable = true;  #Qt/C++ GUI front end for yt-dlp and others
  obs.enable = true;  #Free and open source software for video recording and live streaming
  openshot.enable = true;  #Free, open-source video editor
  spotify.enable = true;  #Play music from the Spotify music service
  vlc.enable = true;  #Cross-platform media player and streaming server

  ## Virtualizations
  bottles.enable = true;    #Easy-to-use wineprefix manager
  distrobox.enable = true;    #Wrapper around podman or docker to create and start containers
  incus.enable = true;   #Powerful system container and virtual machine manager
  podman.enable = true;    #A program for managing pods, containers and container images
  quickemu.enable = true;    #Quickly create and run optimised Windows, macOS and Linux virtual machines
  virt-manager.enable = true;    #Desktop user interface for managing virtual machines
  wine.enable = true;    #Open Source implementation of the Windows API on top of X, OpenGL, and Unix

  ## Art Dev Tools
  blender.enable = true;    #3D Creation/Animation/Publishing System
  darktable.enable = true;    #Virtual lighttable and darkroom for photographers
  gimp.enable = true;    #GNU Image Manipulation Program
  godot.enable = true;    #Free and Open Source 2D and 3D game engine
  inkscape.enable = true;    #Vector graphics editor
  krita.enable = true;    #Free and open source painting application

  ## List packages installed in system profile. To search, run:
  ## $ nix search wget
  environment.systemPackages = with pkgs; [

    ## Godot Dev Tools
    gcc14  #GNU Compiler Collection, version 14.1.0 (wrapper script)
    pkg-config  #Tool that allows packages to find out information about other packages (wrapper script)
    scons  #Improved, cross-platform substitute for Make
    python3Full  #High-level dynamically-typed programming language

  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.11";
}
