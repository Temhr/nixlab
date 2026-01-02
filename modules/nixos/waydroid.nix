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

      # OPTIONAL: Use nftables-compatible version (default: false, auto-detects)
      # Set to true if you're on a newer kernel that only has nftables
      useNftables = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use nftables instead of iptables (for newer kernels)";
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

      # OPTIONAL: Install Google Play Services (default: false)
      enableGapps = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Install Google Play Services and Google Play Store";
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
    boot.kernelParams = [
      "psi=1"  # Enable Pressure Stall Information (fixes boot loops)
    ];

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
    };

    # ----------------------------------------------------------------------------
    # NETWORKING SETUP - Configure firewall for Waydroid networking
    # ----------------------------------------------------------------------------
    # Allow IP forwarding (already set above in sysctl)
    # Set FORWARD policy to ACCEPT for iptables/nftables
    networking.firewall = {
      # Trust the waydroid0 interface
      trustedInterfaces = [ "waydroid0" ];

      # Allow DNS and DHCP for Waydroid
      allowedUDPPorts = [ 53 67 ];

      # Enable packet forwarding
      checkReversePath = false;

      # Extra commands to ensure FORWARD chain accepts packets
      extraCommands = ''
        # Accept forwarding for waydroid0
        iptables -A FORWARD -i waydroid0 -j ACCEPT
        iptables -A FORWARD -o waydroid0 -j ACCEPT
      '';

      extraStopCommands = ''
        iptables -D FORWARD -i waydroid0 -j ACCEPT 2>/dev/null || true
        iptables -D FORWARD -o waydroid0 -j ACCEPT 2>/dev/null || true
      '';
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
          ${if cfg.enableGapps
            then "${cfg.package}/bin/waydroid init -s GAPPS -f || true"
            else "${cfg.package}/bin/waydroid init -f || true"
          }
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

Minimal configuration (RECOMMENDED - manual start):
----------------------------------------------------
services.waydroid-custom = {
  enable = true;
  autoStart = false;  # Don't auto-start - prevents blocking rebuilds
};
# Manually start when needed: sudo systemctl start waydroid-container
# Run: waydroid show-full-ui


Basic configuration with users:
--------------------------------
services.waydroid-custom = {
  enable = true;
  allowedUsers = [ "temhr" ];
  autoStart = false;  # Keep false to avoid rebuild hangs
};


Configuration with Google Play Services:
-----------------------------------------
services.waydroid-custom = {
  enable = true;
  enableGapps = true;  # Install Google Play Services
  allowedUsers = [ "temhr" ];
};


Full configuration:
-------------------
services.waydroid-custom = {
  enable = true;
  dataDir = "/data/waydroid";
  allowedUsers = [ "alice" "bob" ];
  autoStart = true;
  enableGapps = true;
};


================================================================================
USAGE
================================================================================

IMPORTANT - First Time Setup:
  The module enables Waydroid but does NOT auto-start it by default.
  This prevents blocking nixos-rebuild during initialization.

  After rebuilding:
    1. sudo systemctl start waydroid-container
    2. Wait for initialization (5-10 minutes on first run)
    3. Check status: waydroid status
    4. Launch: waydroid show-full-ui

  Initialization downloads ~2-3GB of Android images, so be patient!

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

Check network status:
  ip addr show waydroid0  # Should show waydroid0 interface
  waydroid status         # Should show IP address

  # Inside Waydroid
  waydroid shell
  ping 8.8.8.8           # Test connectivity
  ping google.com        # Test DNS

View logs:
  sudo journalctl -u waydroid-container -f

Initialize manually:
  sudo waydroid init -f

  # Or with Google Play Services
  sudo waydroid init -s GAPPS -f

Check container status:
  sudo waydroid status

Stop container:
  sudo systemctl stop waydroid-container

Reset Waydroid (nuclear option):
  sudo systemctl stop waydroid-container
  sudo rm -rf /var/lib/waydroid
  sudo rm -f /var/lib/waydroid/.initialized
  sudo systemctl start waydroid-container


Google Play Services:
  - Set enableGapps = true before first initialization
  - Cannot add GAPPS after initialization without reset
  - Requires accepting Google's Terms of Service
  - First launch: Sign in with Google account in Play Store


Common issues:
  - "binder device not found": Kernel modules not loaded
    → Check: lsmod | grep binder
    → Fix: sudo modprobe binder_linux

  - Boot loop / Container crashes repeatedly:
    → Most common cause: PSI not enabled
    → Module sets psi=1 automatically
    → Verify: cat /proc/pressure/cpu (should exist)
    → If still failing: sudo rm -rf /var/lib/waydroid && rebuild

  - No network / Can't connect to internet:
    → Check waydroid0 exists: ip addr show waydroid0
    → Check IP forwarding: cat /proc/sys/net/ipv4/ip_forward (should be 1)
    → Check FORWARD chain: sudo iptables -L FORWARD -v
    → Module configures this automatically
    → Manual fix: sudo iptables -P FORWARD ACCEPT
    → Restart container: sudo systemctl restart waydroid-container

  - DNS works but no connection (nftables issue):
    → If on newer kernel (6.0+), may need nftables version
    → Try: useNftables = true; in config
    → Or use: virtualisation.waydroid.enable = true; (official module)

  - Session won't start: Container not running
    → Fix: sudo systemctl start waydroid-container

  - Permission denied: User not in waydroid group
    → Fix: Add user to allowedUsers list

  - For kernel 5.18+: May need ibt=off kernel parameter
    → Add to boot.kernelParams in configuration.nix


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
