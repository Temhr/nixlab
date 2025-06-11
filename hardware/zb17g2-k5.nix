{  config, pkgs, ... }: {
  imports = [
    ./common/global
    ./common/optional
    ./common/optional/wifi-fix.nix
    ./common/optional/drives.nix
    ./common/optional/drives-additional.nix
    #./zb17g2-k5/disko-impermanence.nix
    #./zb17g2-k5/boilerplate.nix
  ];

  # Choose between these choices: "none" "k" "p"
  driver-nvidia.quadro = "k";

  mount-home.enable = true; #mounts home drive
  mount-shelf.enable = true; #mounts shelf drive in home directory
  #mount-mirror.enable = true; #mounts mirror drive
  mount-mirk1.enable = true; #mounts mirk1 nfs
  mount-mirk3.enable = true; #mounts mirk3 nfs


  # Enable and configure the WiFi fix
  hardware.wifi-fix = {
    enable = true;
    interface = "wlp61s0";        # Your WiFi interface
    gateway = "192.168.0.1";      # Your router's IP
    watchdogInterval = 120;       # Check every 2 minutes
    driver = "iwlwifi";           # Intel WiFi driver

    # Optional: disable specific features if needed
    enableWatchdog = true;        # Enable automatic monitoring
    enableResumefix = true;       # Fix WiFi after suspend/resume
    powerSaveDisable = true;      # Disable power saving

    # Optional: extra driver configuration
    extraModprobeConfig = ''
      # Uncomment if you need these for your specific card
      # options iwlwifi 11n_disable=1
      # options iwlwifi swcrypto=1
    '';
  };

}
