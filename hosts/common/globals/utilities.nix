{ config, lib, pkgs, ... }: {

  environment.systemPackages = with pkgs; [
    ## Terminal Utilities
    bat  #Cat(1) clone with syntax highlighting and Git integration
    busybox  #Tiny versions of common UNIX utilities in a single small executable
    colordiff  #Wrapper for 'diff' that produces the same output but with pretty 'syntax' highlighting
    doas  #Executes the given command as another user
    eza  #Modern, maintained replacement for ls
    unstable.fastfetch  #Like neofetch, but much faster because written in C
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

    ## Network Management
    ethtool  #Utility for controlling network drivers and hardware
    iperf  #Tool to measure IP bandwidth using UDP or TCP
    nettools  #A set of tools for controlling the network subsystem in Linux
    nfs-utils  #Linux user-space NFS utilities
    nmap  #A free and open source utility for network discovery and security auditing
    tcpdump  #Network sniffer
    traceroute  #Tracks the route taken by packets over an IP network
    whois  #Intelligent WHOIS client from Debian

    ## Device Management
    switcheroo-control  #D-Bus service to check the availability of dual-GPU
    pciutils  #A collection of programs for inspecting and manipulating configuration of PCI devices
    ncdu  #Disk usage analyzer with an ncurses interface
    furmark  #OpenGL and Vulkan Benchmark and Stress Test
    clinfo  #Print all known information about all available OpenCL platforms and devices in the system
    glxinfo  #Test utilities for OpenGL
    lshw-gui  #Provide detailed information on the hardware configuration of the machine
    usbutils  #Tools for working with USB devices, such as lsusb

    ## File Management
    wget  #Tool for retrieving files using HTTP, HTTPS, and FTP
    rsync  #Fast incremental file transfer utility
    curl  #A command line tool for transferring files with URL syntax

    ## Secret Management
    keepassxc  #Offline password manager with many features.

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

    ## Terminal File Managers
    mc  #File Manager and User Shell for the GNU Project, known as Midnight Commander
    #ranger  #File manager with minimalistic curses interface
    #lf  #Terminal file manager written in Go and heavily inspired by ranger
    #nnn  #Small ncurses-based file browser forked from noice
    #vifm-full  #Vi-like file manager; Includes support for optional features
    #yazi  #Blazing fast terminal file manager written in Rust, based on async I/O

    ## Version Control
    git  #Distributed version control system
    github-desktop #GUI for managing Git and GitHub

    ##Applications
    home-manager  #Nix-based user environment configurator
  ];

  programs.adb.enable = true; #Whether to configure system to use Android Debug Bridge (adb). To grant access to a user, it must be part of adbusers group


  programs.firefox = {
    enable = true;
    languagePacks = [ "en-CA" ];

    /* ---- POLICIES ---- */
    # Check about:policies#documentation for options.
    policies = {
      DisableAccounts = true;  #Disable account-based services, including sync
      DisableFirefoxAccounts = true;  #Disable account-based services, including sync
      DisableFirefoxScreenshots = true;  #Disable the Firefox Screenshots feature
      DisableFirefoxStudies = true;  #Prevent Firefox from running studies
      DisablePocket = true;  #saves webpages to Pocket
      DisableTelemetry = true; #Turn off Telemetry.
      DisplayBookmarksToolbar = "always"; # alternatives: "always" or "newtab"
      DisplayMenuBar = "default-on"; # alternatives: "always", "never" or "default-off"
      DontCheckDefaultBrowser = true;
      #Enable or disable Content Blocking and optionally lock it
      EnableTrackingProtection = {
        Value= true;  #true, tracking protection is enabled by default in regular and private browsing
          Locked = true;
        Cryptomining = true;  #true, cryptomining scripts on websites are blocked
        Fingerprinting = true;  #true, fingerprinting scripts on websites are blocked
      };
      OverrideFirstRunPage = "";  #blank if you want to disable the first run page
      OverridePostUpdatePage = "";  #blank if you want to disable the post-update page
      SearchBar = "unified"; # alternative: "separate"

      /* ---- EXTENSIONS ---- */
      # Check about:support for extension/add-on ID strings.
      # Valid strings for installation_mode are "allowed", "blocked",
      # "force_installed" and "normal_installed".
      ExtensionSettings = {
        "*".installation_mode = "blocked"; # blocks all addons except the ones specified below
        # Enhancer for YouTube:
        "enhancerforyoutube@maximerf.addons.mozilla.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/enhancer-for-youtube/latest.xpi";
          installation_mode = "force_installed";
        };
        # floccus bookmarks sync:
        "floccus@handmadeideas.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/floccus/latest.xpi";
          installation_mode = "force_installed";
        };
        # KeePassXC-Browser:
        "keepassxc-browser@keepassxc.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/keepassxc-browser/latest.xpi";
          installation_mode = "force_installed";
        };
        # Privacy Badger:
        "jid1-MnnxcxisBPnSXQ@jetpack" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
          installation_mode = "force_installed";
        };
        # Reddit Enhancement Suite:
        "jid1-xUfzOsOFlzSOXg@jetpack" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/reddit-enhancement-suite/latest.xpi";
          installation_mode = "force_installed";
        };
        # Sort Bookmarks:
        "sort-bookmarks@heftig" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/sort-bookmarks-webext/latest.xpi";
          installation_mode = "force_installed";
        };
        # uBlock Origin:
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        # Video Speed Controller:
        "{7be2ba16-0f1e-4d93-9ebc-5164397477a9}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/videospeed/latest.xpi";
          installation_mode = "force_installed";
        };
        # Youtube Playlist Duration Calculator:
        "{36d78ab3-8f38-444a-baee-cb4a0cadbf98}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/youtube-playlist-duration-calc/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };
  };

}
