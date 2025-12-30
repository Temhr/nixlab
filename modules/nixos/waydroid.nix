{ config, lib, pkgs, ... }:

let
  cfg = config.services.waydroid-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.waydroid-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Waydroid Android container service";

      # OPTIONAL: Waydroid package to use (default: pkgs.waydroid)
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.waydroid;
        defaultText = lib.literalExpression "pkgs.waydroid";
        description = "The Waydroid package to use";
      };

      # OPTIONAL: Data directory (default: /var/lib/waydroid)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/waydroid";
        example = "/data/waydroid";
        description = "Directory for Waydroid data and images";
      };

      # OPTIONAL: Android images directory (default: /var/lib/waydroid/images)
      imagesDir = lib.mkOption {
        type = lib.types.path;
        default = "${cfg.dataDir}/images";
        defaultText = lib.literalExpression ''"''${config.services.waydroid-custom.dataDir}/images"'';
        description = "Directory for Android system images";
      };

      # OPTIONAL: Users allowed to use Waydroid (default: [])
      allowedUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "alice" "bob" ];
        description = "Users allowed to access Waydroid (empty = all users)";
      };

      # OPTIONAL: Auto-start container on boot (default: false)
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatically start Waydroid container on boot";
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # ----------------------------------------------------------------------------
    # KERNEL MODULES - Enable required kernel modules
    # ----------------------------------------------------------------------------
    boot.kernelModules = [
      "binder_linux"
      "ashmem_linux"
    ];

    # ----------------------------------------------------------------------------
    # KERNEL PARAMETERS - Required for Waydroid
    # ----------------------------------------------------------------------------
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
    };

    # ----------------------------------------------------------------------------
    # DIRECTORY SETUP - Create necessary directories with proper permissions
    # ----------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.imagesDir} 0755 root root -"
    ];

    # ----------------------------------------------------------------------------
    # WAYDROID CONTAINER SERVICE - Main container management service
    # ----------------------------------------------------------------------------
    systemd.services.waydroid-container = {
      description = "Waydroid Android Container";
      wantedBy = lib.mkIf cfg.autoStart [ "multi-user.target" ];
      after = [ "network.target" ];

      path = [ cfg.package ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${cfg.package}/bin/waydroid container start";
        ExecStop = "${cfg.package}/bin/waydroid container stop";
        Restart = "on-failure";
        RestartSec = "10s";

        # Environment
        Environment = [
          "WAYDROID_DIR=${cfg.dataDir}"
        ];

        # Security
        PrivateTmp = true;
      };

      # Initialize Waydroid on first run
      preStart = ''
        # Initialize Waydroid if not already initialized
        if [ ! -f ${cfg.dataDir}/.initialized ]; then
          echo "Initializing Waydroid..."
          ${cfg.package}/bin/waydroid init -f || true
          touch ${cfg.dataDir}/.initialized
        fi
      '';
    };

    # ----------------------------------------------------------------------------
    # USER PERMISSIONS - Add users to waydroid group if specified
    # ----------------------------------------------------------------------------
    users.groups.waydroid = {};

    users.users = lib.mkIf (cfg.allowedUsers != []) (
      lib.listToAttrs (map (user: {
        name = user;
        value = {
          extraGroups = [ "waydroid" ];
        };
      }) cfg.allowedUsers)
    );

    # ----------------------------------------------------------------------------
    # ENVIRONMENT - Make Waydroid available system-wide
    # ----------------------------------------------------------------------------
    environment.systemPackages = [ cfg.package ];

    # ----------------------------------------------------------------------------
    # VIRTUALISATION - Enable LXC for container support
    # ----------------------------------------------------------------------------
    virtualisation.lxc.enable = true;
  };
}

/*
================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration:
----------------------
services.waydroid-custom = {
  enable = true;
};
# Run: waydroid show-full-ui


Basic configuration with users:
--------------------------------
services.waydroid-custom = {
  enable = true;
  allowedUsers = [ "temhr" ];
  autoStart = false;
};


Full configuration:
-------------------
services.waydroid-custom = {
  enable = true;
  dataDir = "/data/waydroid";
  allowedUsers = [ "alice" "bob" ];
  autoStart = true;
};


================================================================================
USAGE
================================================================================

First time setup:
  # System will initialize automatically on first service start
  sudo systemctl start waydroid-container

Starting Waydroid:
  # Start container (if not auto-starting)
  sudo systemctl start waydroid-container

  # Launch Waydroid UI
  waydroid show-full-ui

Using Waydroid:
  # Session commands (as user)
  waydroid session start       # Start user session
  waydroid session stop        # Stop user session

  # App management
  waydroid app install app.apk # Install Android app
  waydroid app list            # List installed apps
  waydroid app launch com.example.app

  # Show Android UI
  waydroid show-full-ui        # Full Android interface

Advanced configuration:
  # Properties can be set with
  waydroid prop set <property> <value>

  # Example: Change DPI
  sudo waydroid prop set ro.sf.lcd_density 320


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status waydroid-container

View logs:
  sudo journalctl -u waydroid-container -f

Initialize manually:
  sudo waydroid init -f

Check container status:
  sudo waydroid status

Stop container:
  sudo systemctl stop waydroid-container

Reset Waydroid (nuclear option):
  sudo systemctl stop waydroid-container
  sudo rm -rf /var/lib/waydroid
  sudo systemctl start waydroid-container


Common issues:
  - "binder device not found": Kernel modules not loaded
    → Check: lsmod | grep binder
    → Fix: sudo modprobe binder_linux

  - Session won't start: Container not running
    → Fix: sudo systemctl start waydroid-container

  - Permission denied: User not in waydroid group
    → Fix: Add user to allowedUsers list


================================================================================
NOTES
================================================================================

Requirements:
  - Wayland compositor (required for Waydroid)
  - Kernel modules: binder_linux, ashmem_linux
  - LXC support (enabled automatically)

Architecture:
  - Container runs as system service
  - User sessions run per-user
  - Data stored in dataDir (/var/lib/waydroid by default)

Performance:
  - Native Android container (not emulation)
  - Near-native performance
  - GPU acceleration supported

Images:
  - Downloaded automatically on first init
  - Stored in imagesDir
  - Can be updated with: sudo waydroid upgrade

*/
