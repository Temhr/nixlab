# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  #Enable Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixtop"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Toronto";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_CA.UTF-8";

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  #services.xserver.displayManager.gdm.enable = true;
  #services.xserver.desktopManager.gnome.enable = true;
  # Enable Plasma6
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
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

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.temhr = {
    isNormalUser = true;
    description = "Temhr";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "temhr";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Install firefox.
  programs.firefox = {
    enable = true;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    ## Terminal Utilities
    busybox  #Tiny versions of common UNIX utilities in a single small executable
    colordiff  #Wrapper for 'diff' that produces the same output but with pretty 'syntax' highlighting
    doas  #Executes the given command as another user
    fastfetch  #Like neofetch, but much faster because written in C
    logrotate  #Rotates and compresses system logs
    lsof  #A tool to list open files
    screen  #A window manager that multiplexes a physical terminal
    tmux  #Terminal multiplexer
    tealdeer #Very fast implementation of tldr in Rust

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

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Limit the number of generations to keep
  boot.loader.systemd-boot.configurationLimit = 5;
  #boot.loader.grub.configurationLimit = 10;
  # Perform garbage collection weekly to maintain low disk usage
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 1w";
  };
  # Optimize storage
  # You can also manually optimize the store via:
  #    nix-store --optimise
  # Refer to the following link for more details:
  # https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-auto-optimise-store
  nix.settings.auto-optimise-store = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
