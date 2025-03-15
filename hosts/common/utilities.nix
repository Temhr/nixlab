{ config, lib, pkgs, ... }: {

  environment.systemPackages = with pkgs; [

    ## NixOS Related Tools
    cachix  #Command-line client for Nix binary cache hosting https://cachix.org

    ## Terminal Utilities
    appimage-run  #https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-appimageTools
    bat  #Cat(1) clone with syntax highlighting and Git integration
    busybox  #Tiny versions of common UNIX utilities in a single small executable
    colordiff  #Wrapper for 'diff' that produces the same output but with pretty 'syntax' highlighting
    doas  #Executes the given command as another user
    eza  #Modern, maintained replacement for ls
    unstable.fastfetch  #Like neofetch, but much faster because written in C
    unstable.fzf  #Command-line fuzzy finder written in Go
    unstable.git #Distributed version control system
    jq  #Lightweight and flexible command-line JSON processor
    less  #More advanced file pager (program that displays text files) than 'more'
    libxml2  #XML parsing library for C
    logrotate  #Rotates and compresses system logs
    lsof  #A tool to list open files
    parted  #Create, destroy, resize, check, and copy partitions
    screen  #A window manager that multiplexes a physical terminal
    tmux  #Terminal multiplexer
    tealdeer #Very fast implementation of tldr in Rust
    moreutils #Growing collection of the unix tools that nobody thought to write long ago when unix was young
    zoxide  # Fast cd command that learns your habits

    ## Task Scheduling
    at  #The classical Unix `at' job scheduling command
    cron  #Daemon for running commands at specific times (Vixie Cron)

    ## Network Management
    bridge-utils  #Userspace tool to configure linux bridges (deprecated in favour or iproute2)
    ethtool  #Utility for controlling network drivers and hardware
    iperf  #Tool to measure IP bandwidth using UDP or TCP
    iproute2  #Collection of utilities for controlling TCP/IP networking and traffic control in Linux
    nettools  #A set of tools for controlling the network subsystem in Linux
    nfs-utils  #Linux user-space NFS utilities
    nmap  #A free and open source utility for network discovery and security auditing
    tcpdump  #Network sniffer
    traceroute  #Tracks the route taken by packets over an IP network
    whois  #Intelligent WHOIS client from Debian

    ## Device Management
    pciutils  #A collection of programs for inspecting and manipulating configuration of PCI devices
    ncdu  #Disk usage analyzer with an ncurses interface
    clinfo  #Print all known information about all available OpenCL platforms and devices in the system
    glxinfo  #Test utilities for OpenGL
    lshw-gui  #Provide detailed information on the hardware configuration of the machine
    usbutils  #Tools for working with USB devices, such as lsusb
    sysfsutils   # For systool

    ## File Management
    wget  #Tool for retrieving files using HTTP, HTTPS, and FTP
    rsync  #Fast incremental file transfer utility
    curl  #A command line tool for transferring files with URL syntax

    ## Secret Management
    keepassxc  #Offline password manager with many features.

    ## System Resource Monitors
    atop  #Console system performance monitor
    btop  #A monitor of resources
    iftop  #Display bandwidth usage on a network interface
    iotop  #A tool to find out the processes doing the most IO
    htop  #An interactive process viewer
    nvtopPackages.intel  #(h)top like task monitor for AMD, Adreno, Intel and NVIDIA GPUs
    nvtopPackages.nvidia  #(h)top like task monitor for AMD, Adreno, Intel and NVIDIA GPUs
    perf-tools  #Performance analysis tools based on Linux perf_events (aka perf) and ftrace
    wavemon  #Ncurses-based monitoring application for wireless network devices

    ## Text Editors
    nano  #Small, user-friendly console text editor
    vim  #The most popular clone of the VI editor
    unstable.neovim  #Vim text editor fork focused on extensibility and agility
      alejandra #Uncompromising Nix Code Formatter
    zed  #Novel data lake based on super-structured data

    ## Terminal File Managers
    mc  #File Manager and User Shell for the GNU Project, known as Midnight Commander
    #ranger  #File manager with minimalistic curses interface
    #lf  #Terminal file manager written in Go and heavily inspired by ranger
    #nnn  #Small ncurses-based file browser forked from noice
    #vifm-full  #Vi-like file manager; Includes support for optional features
    #yazi  #Blazing fast terminal file manager written in Rust, based on async I/O

    ##Applications

    kdePackages.partitionmanager  #Manage the disk devices, partitions and file systems on your computer
    unstable.kdePackages.kcalc  #Calculator offering everything a scientific calculator does, and more
    unstable.home-manager  #Nix-based user environment configurator
    # Media
    ffmpeg  #A complete, cross-platform solution to record, convert and stream audio and video
    unstable.scrcpy  #Display and control Android devices over USB or TCP/IP
    simplescreenrecorder  #A screen recorder for Linux

  ];

  programs.adb.enable = true; #Whether to configure system to use Android Debug Bridge (adb). To grant access to a user, it must be part of adbusers group

  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
}
