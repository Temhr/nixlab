{ inputs, config, lib, pkgs, ...}: {

  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  # Create a persistent directory
  fileSystems."/persistent" = {
    device = "/dev/disk/by-label/root";
    fsType = "ext4";
    neededForBoot = true;
    options = ["noatime"];
  };

  # Link home directory to persistent storage
  fileSystems."/home" = {
    device = "/persistent/home";
    fsType = "none";
    options = ["bind"];
  };

  # Enable tmpfs for root
  boot.initrd.systemd.enable = true;
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  # Configure which files/directories to persist
  environment.persistence."/persistent" = {
    directories = [
      "/var/log"
      "/var/lib/"
      "/etc/nixos"
      "/etc/ssh"
      "/etc/NetworkManager/system-connections"
      # Add other directories you want to persist
    ];
    files = [
      "/etc/machine-id"
      # Add other files you want to persist
    ];
    users.temhr = {
      directories = [
        ".bin"
        ".bash"
        ".ssh"
        ".gnupg"
        ".config"
        ".local"
        ".mozilla"
        ".var"
        ".nv"
        ".pki"
        ".ssh"
        ".ssr"
        ".wine"
        ".zen"
        "bin"
        "Desktop"
        "Documents"
        "Downloads"
        "Music"
        "Pictures"
        "Projects"
        "Videos"
        "nixlab"
        # Add other user directories you want to persist
      ];
      files = [
        ".bashrc"
        ".bash_history"
        ".bash_profile"
        ".gitconfig"
        ".inputrc"
        # Add other user files you want to persist
      ];
    };
  };

  # Configure NFS mounts
  fileSystems."/mnt/mirk1" = {
    device = "192.168.0.201:/mirror";
    fsType = "nfs";
    options = [
      "x-systemd.automount" "noauto"
      "x-systemd.after=network-online.target"
      "x-systemd.idle-timeout=60"
    ];
  };

  fileSystems."/mnt/mirk3" = {
    device = "192.168.0.204:/mirror";
    fsType = "nfs";
    options = [
      "x-systemd.automount" "noauto"
      "x-systemd.after=network-online.target"
      "x-systemd.idle-timeout=60"
    ];
  };

  systemd.tmpfiles.rules = [ "d /mnt 1744 temhr user " ];
}
