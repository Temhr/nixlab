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
        description = ''
          Directory for Waydroid system data (images, rootfs, overlays).
          This is the main directory containing Android system images and container configuration.
          User-specific data still goes to ~/.local/share/waydroid/data per user.
        '';
      };

      # OPTIONAL: Android images directory (default: /var/lib/waydroid/images)
      imagesDir = lib.mkOption {
        type = lib.types.path;
        default = "${cfg.dataDir}/images";
        defaultText = lib.literalExpression ''"''${config.services.waydroid-custom.dataDir}/images"'';
        description = ''
          Directory for Android system images (system.img, vendor.img).
          These are large files (~1-2GB each) downloaded during initialization.
        '';
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
    # WAYDROID CONFIG - Create config file pointing to custom dataDir
    # ----------------------------------------------------------------------------
    environment.etc."gbinder.d/waydroid.conf".text = ''
      [Protocol]
      /dev/binder = aidl3
      /dev/vndbinder = aidl3
      /dev/hwbinder = hidl

      [ServiceManager]
      /dev/binder = aidl3
      /dev/vndbinder = aidl3
      /dev/hwbinder = hidl
    '';

    # Create a wrapper script that sets the correct data directory
    systemd.services.waydroid-container-setup = {
      description = "Waydroid Data Directory Setup";
      before = [ "waydroid-container.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        # Create waydroid config directory if it doesn't exist
        mkdir -p /var/lib/waydroid

        # Create or update the waydroid config to use custom dataDir
        if [ "${cfg.dataDir}" != "/var/lib/waydroid" ]; then
          # Create symlink if using custom location
          if [ ! -L /var/lib/waydroid ] && [ -d /var/lib/waydroid ]; then
            # Backup existing data if present
            if [ -d /var/lib/waydroid/images ]; then
              echo "Found existing data in /var/lib/waydroid, moving to ${cfg.dataDir}..."
              mkdir -p ${cfg.dataDir}
              cp -rn /var/lib/waydroid/* ${cfg.dataDir}/ 2>/dev/null || true
              rm -rf /var/lib/waydroid
            else
              rm -rf /var/lib/waydroid
            fi
          fi

          # Create symlink from default location to custom location
          if [ ! -e /var/lib/waydroid ]; then
            ln -sfn ${cfg.dataDir} /var/lib/waydroid
          fi
        fi
      '';
    };

    # ----------------------------------------------------------------------------
    # WAYDROID CONTAINER SERVICE - Main container management service
    # ----------------------------------------------------------------------------
    systemd.services.waydroid-container = {
      description = "Waydroid Android Container";
      wantedBy = lib.mkIf cfg.autoStart [ "multi-user.target" ];
      after = [ "network.target" "waydroid-container-setup.service" ];
      requires = [ "waydroid-container-setup.service" ];

      # Don't block system boot/rebuild if service fails
      unitConfig = {
        # Service is allowed to fail without blocking other services
        DefaultDependencies = false;
      };

      path = [ cfg.package ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${cfg.package}/bin/waydroid container start";
        ExecStop = "${cfg.package}/bin/waydroid container stop";

        # Timeout and restart configuration
        TimeoutStartSec = "90s";  # Give it time to initialize
        TimeoutStopSec = "30s";   # Don't hang on shutdown
        Restart = "no";           # Don't auto-restart on failure

        # If it fails to start, don't block the system
        SuccessExitStatus = "0 1"; # Accept both success and some failures

        # Environment
        Environment = [
          "WAYDROID_DIR=${cfg.dataDir}"
          "XDG_DATA_HOME=${cfg.dataDir}"
        ];

        # Security
        PrivateTmp = true;
      };

      # Initialize Waydroid on first run
      preStart = ''
        # Initialize Waydroid if not already initialized
        if [ ! -f ${cfg.dataDir}/.initialized ]; then
          echo "Initializing Waydroid (this may take a few minutes)..."
          ${if cfg.enableGapps
            then "${cfg.package}/bin/waydroid init -s GAPPS -f || true"
            else "${cfg.package}/bin/waydroid init -f || true"
          }
          touch ${cfg.dataDir}/.initialized
          echo "Waydroid initialized. You can start it with: sudo systemctl start waydroid-container"
        fi
      '';

      # Post-start check with grace period
      postStart = ''
        # Give container a moment to settle
        sleep 2

        # Verify container actually started
        if ! ${cfg.package}/bin/waydroid status >/dev/null 2>&1; then
          echo "Warning: Waydroid container may not have started properly"
          echo "Check status with: sudo systemctl status waydroid-container"
          exit 0  # Don't fail the service
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


Configuration with Google Play Services:
-----------------------------------------
services.waydroid-custom = {
  enable = true;
  enableGapps = true;  # Install Google Play Services
  allowedUsers = [ "temhr" ];
};


Full configuration with custom location:
-----------------------------------------
services.waydroid-custom = {
  enable = true;
  dataDir = "/data/waydroid";  # System images and container config
  allowedUsers = [ "alice" "bob" ];
  autoStart = false;
  enableGapps = true;
};

# Note: User data still goes to ~/.local/share/waydroid/data per user
# To back up everything, include both locations:
#   - /data/waydroid (system-wide: images, rootfs, overlays)
#   - ~/.local/share/waydroid (per-user: Android apps and data)


================================================================================
DATA LOCATIONS
================================================================================

Waydroid uses TWO separate data locations:

1. SYSTEM-WIDE DATA (dataDir, default: /var/lib/waydroid):
   /var/lib/waydroid/
   ├── images/          # Android system images (system.img, vendor.img) ~2-3GB
   ├── rootfs/          # Mount point for Android filesystem (runtime)
   ├── overlay/         # Read-only system customizations
   ├── overlay_rw/      # Read-write system modifications
   ├── overlay_work/    # Overlay work directory
   ├── lxc/            # Container configuration
   └── .initialized    # Initialization marker

2. PER-USER DATA (~/.local/share/waydroid for each user):
   ~/.local/share/waydroid/
   └── data/           # Android user data (apps, settings, files)
       └── media/0/    # Android internal storage (/sdcard)

BACKUP STRATEGY:
  System-wide (one backup):
    - Back up ${dataDir} (contains images and configuration)

  Per-user (backup for each user):
    - Back up ~/.local/share/waydroid/data for each user
    - This contains installed apps, app data, and Android files

  Example backup locations if dataDir = "/data/waydroid":
    - /data/waydroid                        # System images
    - /home/alice/.local/share/waydroid/data   # Alice's apps
    - /home/bob/.local/share/waydroid/data     # Bob's apps


================================================================================
USAGE
================================================================================

First time setup:
  # System will initialize automatically on first rebuild
  # If autoStart = false, manually start when needed:
  sudo systemctl start waydroid-container

  # Initialization happens in background and won't block system

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

Check disk usage:
  # System images (large files)
  du -sh /var/lib/waydroid/images

  # User data (apps and files)
  du -sh ~/.local/share/waydroid/data

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
  sudo rm -rf /var/lib/waydroid  # System data
  sudo rm -rf ~/.local/share/waydroid  # Your user data
  sudo rm -f /var/lib/waydroid/.initialized
  sudo systemctl start waydroid-container


Data Management:
  # Where is my data?
  System images:   ${dataDir}/images/  (or /var/lib/waydroid if using default)
  Container files: ${dataDir}/rootfs/, overlay_rw/
  User apps/data:  ~/.local/share/waydroid/data/

  # If using custom dataDir, /var/lib/waydroid is a symlink
  ls -la /var/lib/waydroid  # Should show symlink if custom location

  # Access Android storage from Linux
  cd ~/.local/share/waydroid/data/media/0/  # This is /sdcard in Android

  # Move to different location AFTER initial setup
  # 1. Stop container
  sudo systemctl stop waydroid-container

  # 2. Move data (if switching from default)
  sudo mv /var/lib/waydroid /data/waydroid

  # 3. Update config with new dataDir and rebuild
  # The module will create proper symlink

  # Move to different location (requires manual symlinks)
  # Waydroid hardcodes ~/.local/share/waydroid for user data
  # To use different location:
  mv ~/.local/share/waydroid ~/new-location/waydroid
  ln -s ~/new-location/waydroid ~/.local/share/waydroid


Google Play Services:
  - Set enableGapps = true before first initialization
  - Cannot add GAPPS after initialization without reset
  - Requires accepting Google's Terms of Service
  - First launch: Sign in with Google account in Play Store


Common issues:
  - System rebuild hangs:
    → Waydroid service is now non-blocking
    → If it still hangs, stop service first: sudo systemctl stop waydroid-container
    → Then rebuild: sudo nixos-rebuild switch

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

System Integration:
  - Service is non-blocking and won't hang nixos-rebuild
  - Safe to rebuild even with Waydroid running
  - Initialization happens in background on first activation
  - Use autoStart = false for manual control (recommended)
  - Custom dataDir uses symlink from /var/lib/waydroid to your location
  - Module automatically migrates existing data when changing dataDir

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
