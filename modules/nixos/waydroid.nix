{ config, lib, pkgs, ... }:

let
  cfg = config.virtualisation.waydroid-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    virtualisation.waydroid-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Waydroid Android container";

      # OPTIONAL: Waydroid package to use (default: pkgs.waydroid)
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.waydroid;
        defaultText = lib.literalExpression "pkgs.waydroid";
        description = "The Waydroid package to use";
      };

      # OPTIONAL: Where to store Waydroid data (default: /var/lib/waydroid)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/waydroid";
        example = "/data/waydroid";
        description = "Directory for Waydroid data and images";
      };

      # OPTIONAL: Auto-initialize Waydroid on first start (default: true)
      autoInit = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Automatically initialize Waydroid images on first start";
      };

      # OPTIONAL: System image channel (default: "lineage")
      # Options: "lineage" or "vanilla"
      systemChannel = lib.mkOption {
        type = lib.types.enum [ "lineage" "vanilla" ];
        default = "lineage";
        description = "Android system image channel (lineage or vanilla)";
      };

      # OPTIONAL: Include GApps (Google Apps) (default: false)
      includeGApps = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Include Google Apps in the Android image";
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # ----------------------------------------------------------------------------
    # WAYDROID SERVICE - Enable the built-in NixOS Waydroid service
    # ----------------------------------------------------------------------------
    virtualisation.waydroid.enable = true;
    virtualisation.waydroid.package = cfg.package;

    # ----------------------------------------------------------------------------
    # DIRECTORY SETUP - Create necessary directories with proper permissions
    # ----------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

    # ----------------------------------------------------------------------------
    # KERNEL MODULES - Load required kernel modules for Android containerization
    # ----------------------------------------------------------------------------
    boot.kernelModules = [
      "binder_linux"      # Android IPC
      "ashmem_linux"      # Android shared memory
    ];

    # ----------------------------------------------------------------------------
    # INITIALIZATION - Auto-download Android images if requested
    # ----------------------------------------------------------------------------
    systemd.services.waydroid-init = lib.mkIf cfg.autoInit {
      description = "Waydroid Initialization";
      wantedBy = [ "multi-user.target" ];
      after = [ "waydroid-container.service" ];
      wants = [ "waydroid-container.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "waydroid-init" ''
          # Check if Waydroid is already initialized
          if [ ! -f ${cfg.dataDir}/waydroid.cfg ]; then
            echo "Initializing Waydroid..."

            # Build init command with options
            INIT_CMD="${cfg.package}/bin/waydroid init -s ${cfg.systemChannel}"
            ${lib.optionalString cfg.includeGApps ''INIT_CMD="$INIT_CMD -g"''}

            # Initialize Waydroid
            $INIT_CMD || {
              echo "Waydroid initialization failed"
              exit 1
            }

            echo "Waydroid initialized successfully"
          else
            echo "Waydroid already initialized"
          fi
        '';
      };
    };

    # ----------------------------------------------------------------------------
    # ENVIRONMENT - Add Waydroid to system PATH
    # ----------------------------------------------------------------------------
    environment.systemPackages = [ cfg.package ];

    # ----------------------------------------------------------------------------
    # SECURITY - Enable necessary capabilities
    # ----------------------------------------------------------------------------
    security.polkit.enable = true;
  };
}

/*
================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration:
----------------------
virtualisation.waydroid-custom = {
  enable = true;
};
# Start Waydroid: waydroid session start
# Launch UI: waydroid show-full-ui


Configuration with GApps:
-------------------------
virtualisation.waydroid-custom = {
  enable = true;
  includeGApps = true;
  systemChannel = "lineage";
  dataDir = "/data/waydroid";
};


================================================================================
WAYDROID USAGE
================================================================================

First-time setup (if autoInit = false):
  sudo waydroid init -s lineage           # LineageOS without GApps
  sudo waydroid init -s lineage -g        # LineageOS with GApps
  sudo waydroid init -s vanilla           # AOSP vanilla

Start Waydroid session:
  waydroid session start

Launch Android UI:
  waydroid show-full-ui                   # Fullscreen window
  waydroid app launch com.android.settings # Launch specific app

Install APKs:
  waydroid app install /path/to/app.apk

List installed apps:
  waydroid app list

Stop session:
  waydroid session stop


================================================================================
CONFIGURATION FILES
================================================================================

Main config:
  ${cfg.dataDir}/waydroid.cfg

System properties (advanced):
  ${cfg.dataDir}/waydroid_base.prop

To modify system properties:
  sudo waydroid prop set persist.waydroid.width 1920
  sudo waydroid prop set persist.waydroid.height 1080


================================================================================
TROUBLESHOOTING
================================================================================

Check container status:
  sudo systemctl status waydroid-container

View logs:
  sudo journalctl -u waydroid-container -f

Restart services:
  sudo systemctl restart waydroid-container
  waydroid session stop && waydroid session start

Reset Waydroid (WARNING: deletes all data):
  sudo rm -rf ${cfg.dataDir}
  sudo waydroid init

Common issues:
  - "binder: No such device" → Check kernel modules are loaded
  - Session won't start → Check waydroid-container service is running
  - Display issues → Ensure you're running on Wayland (not X11)


================================================================================
REQUIREMENTS
================================================================================

Waydroid requires:
  - Wayland compositor (Sway, Hyprland, GNOME, KDE Plasma on Wayland)
  - Kernel with binder and ashmem support (most modern kernels)
  - NOT compatible with X11 (use Waydroid on Wayland only)

To check if kernel modules are available:
  lsmod | grep binder
  lsmod | grep ashmem

*/
