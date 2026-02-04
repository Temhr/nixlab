{ pkgs, ... }: {

#1) Require system-level privileges
#2) Interact with system hardware, kernel interfaces, or system-wide configurations
#3) Provide background daemons or network services
#4) Benefit from being available to all users

  environment.systemPackages = with pkgs; [
    ## Nix Tools
    cachix                     # Nix binary cache client for sharing build artifacts
    git                        # distributed version control system
    home-manager               # user environment manager for declarative configs

    android-tools              #

    ## System Utilities
    appimage-run               # Run AppImage applications without extracting them
    busybox                    # Single binary with lightweight UNIX utilities
    doas                       # Minimal alternative to sudo for privilege escalation
    logrotate                  # Automatically rotates and compresses system logs
    lsof                       # Lists open files and associated processes
    parted                     # Partition editor for disks
    moreutils                  # Collection of useful Unix utilities

    ## Task Scheduling
    at                         # Schedule one-off tasks to run at a specific time
    cron                       # Daemon to run recurring scheduled tasks

    ## Network Management
    bridge-utils               # Configure and manage network bridges (deprecated)
    dig                        # DNS lookup utility
    ethtool                    # Control and query Ethernet device settings
    iperf                      # Measure network throughput via TCP/UDP tests
    iproute2                   # Modern networking tools (e.g., ip, tc, ss)
    mtr-gui                    # GUI traceroute + ping tool for network diagnostics
    nethogs                    # Real-time bandwidth usage grouped by process
    nettools                   # Legacy networking utilities like ifconfig, netstat
    nfs-utils                  # NFS client/server user-space support
    nmap                       # Network discovery and security auditing tool
    tcpdump                    # Packet capture and analysis tool
    traceroute                 # Track path of packets through network hops
    whois                      # Query ownership and registration of domains/IPs

    ## Device Management
    pciutils                   # Inspect and manipulate PCI device configuration
    usbutils                   # Inspect and interact with USB devices
    sysfsutils                 # Query device information from sysfs
    lshw-gui                   # Hardware lister with graphical interface
    esptool                    # ESP8266 and ESP32 serial bootloader utility

    ## File Management
    curl                       # Transfer data from URLs (HTTP, FTP, etc.)
    rsync                      # Efficient file copying and synchronization
    symlinks                   # Inspect and clean broken symbolic links
    wget                       # Retrieve files from the web via HTTP/S/FTP

    ## Secret/Encryption
    age                        # Simple, modern file encryption tool

    ## System Resource Monitors
    atop                       # Advanced system and process resource monitor
    btop                       # Graphical resource monitor with performance charts
    iftop                      # Monitor real-time network traffic by interface
    iotop                      # Monitor disk I/O usage by process
    htop                       # Interactive process viewer and manager
    lm_sensors                 # Read hardware sensor data (temps, fan speeds, etc.)
    nvtopPackages.intel        # GPU usage monitor for Intel graphics
    nvtopPackages.nvidia       # GPU usage monitor for NVIDIA graphics
    perf-tools                 # Scripts and tools built on Linux perf events
    psmisc                     # Utilities like `pstree`, `killall`, `fuser`
    smartmontools              # Monitor S.M.A.R.T. health of storage drives
    stress-ng                  # Apply configurable system stress for testing
    sysstat                    # Collection of performance monitoring tools for Linux (such as sar, iostat and pidstat)
    wavemon                    # WiFi signal and quality monitor for terminals

    ## Disk & Partition Tools
    kdePackages.partitionmanager  # GUI for managing partitions and filesystems
    usbimager                     # Very minimal GUI app that can write compressed disk images to USB drives
    gparted                       # Graphical disk partitioning tool
  ];

}
