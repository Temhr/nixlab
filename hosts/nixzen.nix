# This is your system's configuration file. Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
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

  services.ignoreLid = {
    enable = true;
    # Optional:
    disableSleepTargets = true;
  };

  ## Enable CUPS to print documents.
  services.printing.enable = true;

  ## Development
  #blender.enable = true;    #3D Creation/Animation/Publishing System
  #godot.enable = true;    #Free and Open Source 2D and 3D game engine
  #vscodium.enable = true; #VS Code without MS branding/telemetry/licensing

  ## Education
  #anki.enable = true;  #Spaced repetition flashcard program

  ## Gaming Packages
  #steam.enable = true;  #Video game digital distribution service and storefront from Valve

  ## Productivity
  #calibre.enable = true;  #Comprehensive e-book software
  #libreoffice.enable = true;  #Comprehensive, professional-quality productivity suite
  #logseq.enable = true;  #Privacy-first, open-source platform for knowledge management and collaboration

  ## Media Packages
  #obs.enable = true;  #Free and open source software for video recording and live streaming
  #spotify.enable = true;  #Play music from the Spotify music service
  #vlc.enable = true;  #Cross-platform media player and streaming server

  ## Virtualizations
  #bottles.enable = true;    #Easy-to-use wineprefix manager
  #distrobox.enable = true;    #Wrapper around podman or docker to create and start containers
  #incus.enable = true;   #Powerful system container and virtual machine manager
  #podman.enable = true;    #A program for managing pods, containers and container images
  #quickemu.enable = true;    #Quickly create and run optimised Windows, macOS and Linux virtual machines
  #virt-manager.enable = true;    #Desktop user interface for managing virtual machines
  #wine.enable = true;    #Open Source implementation of the Windows API on top of X, OpenGL, and Unix

  ## Self-hosted apps and services
  services.grafana-nixlab.enable = false;
  services.loki-nixlab.enable = false;
  services.prometheus-nixlab.enable = false;

  services.syncthing-nixlab = {
    enable = true;
    user = "${config.nixlab.mainUser}";
    group = "users";
    guiPort = 8384;
    guiAddress = "0.0.0.0";
    configDir = "/home/${config.nixlab.mainUser}/.config/syncthing";
    openFirewall = true;
    devices = {
      "nixvat" = {
        id = "5KHDLOC-2FKYN27-2FADIS5-FQTKXOE-B63AEEZ-BYDWKPJ-B24GQUC-6JXTAQP";
        addresses = ["dynamic"];
        introducer = false;
      };
      "Pixel XL" = {
        id = "LU65H6D-KZYP6H3-SGBGPY3-LIN6F2A-32JM2AQ-HN76W2G-ADJMWEH-6EMQXA4";
        addresses = ["dynamic"];
      };
      "Pixel 3a XL" = {
        id = "4CCPARZ-D55MZPY-OMRVLQL-YAQJFKY-5RZXAFQ-MZJ4VSC-E5ZS7VQ-VRCFGAY";
        addresses = ["dynamic"];
      };
    };
    folders = {
      "mirror" = {
        path = "/mirror";
        id = "mirror";
        label = "mirror";
        devices = ["nixvat"];
        type = "sendreceive"; # or "sendonly" or "receiveonly"
      };
      "Phone media" = {
        path = "/mirror/phshare/photos";
        id = "Phone media";
        label = "Phone media";
        devices = ["Pixel XL" "Pixel 3a XL"];
        type = "sendreceive"; # or "sendonly" or "receiveonly"
      };
      "Docs" = {
        path = "/mirror/phshare/docs";
        id = "Docs";
        label = "Docs";
        devices = ["Pixel XL" "Pixel 3a XL"];
        type = "sendreceive"; # or "sendonly" or "receiveonly"
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
