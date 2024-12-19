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
  boot.loader.systemd-boot.configurationLimit = 5;
  #boot.loader.grub.configurationLimit = 10;

  # TODO: Set your hostname
  networking.hostName = "nixtop";

  ## Enable networking
  networking.networkmanager.enable = true;
  ## Set your time zone.
  time.timeZone = "America/Toronto";
  ## Select internationalisation properties.
  i18n.defaultLocale = "en_CA.UTF-8";
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

  # TODO: Configure your system-wide user settings (groups, etc), add more users as needed.
  users.users = {
    # FIXME: Replace with your username
    temhr = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        # TODO: Add your SSH public key(s) here, if you plan on using SSH to connect
      ];
      # TODO: Be sure to add any other groups you need (such as networkmanager, audio, docker, etc)
      extraGroups = [ "networkmanager" "wheel" ];
      packages = with pkgs; [
      #  thunderbird
      ];
    };
  };
  ## Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "temhr";

  ## Install firefox.
  programs.firefox = {
    enable = true;
  };

  ## List packages installed in system profile. To search, run:
  ## $ nix search wget
  environment.systemPackages = with pkgs; [
    ## Terminal Utilities
    bat  #Cat(1) clone with syntax highlighting and Git integration
    busybox  #Tiny versions of common UNIX utilities in a single small executable
    colordiff  #Wrapper for 'diff' that produces the same output but with pretty 'syntax' highlighting
    doas  #Executes the given command as another user
    eza  #Modern, maintained replacement for ls
    fastfetch  #Like neofetch, but much faster because written in C
    fzf  #Command-line fuzzy finder written in Go
    jq  #Lightweight and flexible command-line JSON processor
    logrotate  #Rotates and compresses system logs
    lsof  #A tool to list open files
    screen  #A window manager that multiplexes a physical terminal
    tmux  #Terminal multiplexer
    tealdeer #Very fast implementation of tldr in Rust
    moreutils #Growing collection of the unix tools that nobody thought to write long ago when unix was young
    yadm  #Yet Another Dotfiles Manager
    zoxide  # Fast cd command that learns your habits

    ## Task Scheduling
    at  #The classical Unix `at' job scheduling command
    cron  #Daemon for running commands at specific times (Vixie Cron)
    kdePackages.kcron  #Task scheduler by KDE

    ## Dev Tools
    android-tools  #Android SDK platform tools
    gcc14  #GNU Compiler Collection, version 14.1.0 (wrapper script)
    gdb  #The GNU Project debugger
    gdbgui  #A browser-based frontend for GDB
    gnumake  #A tool to control the generation of non-source files from sources

    ## Network Management
    #autofs5  #Kernel-based automounter
    ethtool  #Utility for controlling network drivers and hardware
    iperf  #Tool to measure IP bandwidth using UDP or TCP
    nettools  #A set of tools for controlling the network subsystem in Linux
    nfs-utils  #Linux user-space NFS utilities
    nmap  #A free and open source utility for network discovery and security auditing
    tcpdump  #Network sniffer
    traceroute  #Tracks the route taken by packets over an IP network
    whois  #Intelligent WHOIS client from Debian

    ## Device Management
    kdePackages.partitionmanager  #Manage the disk devices, partitions and file systems on your computer
    #switcheroo-control  #D-Bus service to check the availability of dual-GPU
    pciutils  #A collection of programs for inspecting and manipulating configuration of PCI devices
    ncdu  #Disk usage analyzer with an ncurses interface
    #furmark  #OpenGL and Vulkan Benchmark and Stress Test
    cachix  #Command-line client for Nix binary cache hosting https://cachix.org
    clinfo  #Print all known information about all available OpenCL platforms and devices in the system
    vulkan-tools  #Khronos official Vulkan Tools and Utilities
    cudaPackages.cudatoolkit  #A wrapper substituting the deprecated runfile-based CUDA installation
    glxinfo  #Test utilities for OpenGL
    lshw-gui  #Provide detailed information on the hardware configuration of the machine
    usbutils  #Tools for working with USB devices, such as lsusb

    ## File Management
    syncthing  #Open Source Continuous File Synchronization
    syncthingtray  #Tray application and Dolphin/Plasma integration for Syncthing
    wget  #Tool for retrieving files using HTTP, HTTPS, and FTP
    rsync  #Fast incremental file transfer utility
    curl  #A command line tool for transferring files with URL syntax

    ## System Resource Monitors
    iotop  #A tool to find out the processes doing the most IO
    htop  #An interactive process viewer
    btop  #A monitor of resources

    ## Text Editors
    nano  #Small, user-friendly console text editor
    vim  #The most popular clone of the VI editor
    neovim  #Vim text editor fork focused on extensibility and agility
      alejandra #Uncompromising Nix Code Formatter
    zed  #Novel data lake based on super-structured data

    ## Version Control
    git  #Distributed version control system
    github-desktop #GUI for managing Git and GitHub

    ## Secret Management
    keepassxc  #Offline password manager with many features.

    ## Terminal File Managers
    mc  #File Manager and User Shell for the GNU Project, known as Midnight Commander
    #ranger  #File manager with minimalistic curses interface
    #lf  #Terminal file manager written in Go and heavily inspired by ranger
    #nnn  #Small ncurses-based file browser forked from noice
    #vifm-full  #Vi-like file manager; Includes support for optional features
    #yazi  #Blazing fast terminal file manager written in Rust, based on async I/O

    ## Browsers
    brave  #Privacy-oriented browser for Desktop and Laptop computers
    microsoft-edge  #The web browser from Microsoft
    google-chrome  #Freeware web browser developed by Google
    #vivaldi  #A Browser for our Friends, powerful and personal

    ## Communication
    discord  #All-in-one cross-platform voice and text chat for gamers
    obs-studio  #Free and open source software for video recording and live streaming
    scrcpy  #Display and control Android devices over USB or TCP/IP
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
