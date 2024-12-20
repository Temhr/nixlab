{ config, lib, pkgs, ... }: {

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
    #switcheroo-control  #D-Bus service to check the availability of dual-GPU
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

  ];
}
