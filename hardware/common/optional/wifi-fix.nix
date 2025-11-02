# WiFi Fix Module for Intel WiFi Cards (especially 7260)
# Save as: modules/wifi-fix.nix or hardware/wifi-fix.nix

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.wifi-fix;
in

{
  options.hardware.wifi-fix = {
    enable = mkEnableOption "WiFi fix for Intel WiFi cards with hang issues";

    interface = mkOption {
      type = types.str;
      default = "wlp61s0";
      description = "The WiFi interface name";
      example = "wlp3s0";
    };

    gateway = mkOption {
      type = types.str;
      default = "192.168.0.1";
      description = "The gateway IP to ping for connectivity checks";
      example = "192.168.1.1";
    };

    watchdogInterval = mkOption {
      type = types.int;
      default = 120;
      description = "How often (in seconds) to check WiFi connectivity";
    };

    driver = mkOption {
      type = types.str;
      default = "iwlwifi";
      description = "The WiFi driver to reload when issues are detected";
      example = "ath9k";
    };

    enableWatchdog = mkOption {
      type = types.bool;
      default = true;
      description = "Enable the WiFi watchdog service";
    };

    enableResumefix = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automatic WiFi fix after suspend/resume";
    };

    powerSaveDisable = mkOption {
      type = types.bool;
      default = true;
      description = "Disable WiFi power saving features";
    };

    extraModprobeConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra modprobe configuration for the WiFi driver";
      example = ''
        options iwlwifi 11n_disable=1
        options iwlwifi swcrypto=1
      '';
    };

    networkManager = mkOption {
      type = types.bool;
      default = true;
      description = "Whether NetworkManager is being used (affects reconnection commands)";
    };
  };

  config = mkIf cfg.enable {
    # Intel WiFi driver configuration
    boot.kernelModules = [ cfg.driver ];

    boot.extraModprobeConfig = ''
      # Disable power saving features that cause WiFi hangs
      options ${cfg.driver} power_save=0
      ${optionalString (cfg.driver == "iwlwifi") ''
      options iwlwifi uapsd_disable=1
      options iwlwifi wd_disable=0
      ''}
      ${cfg.extraModprobeConfig}
    '';

    # Journal-watching service (catches failures instantly)
    systemd.services.wifi-driver-monitor = {
      description = "Monitor for iwlwifi driver crashes";
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10";
        ExecStart = pkgs.writeShellScript "wifi-driver-monitor" ''
          ${pkgs.systemd}/bin/journalctl -f -u NetworkManager -k | while read -r line; do
            if echo "$line" | grep -q "iwlwifi.*enqueue_hcmd failed"; then
              echo "$(date): Detected iwlwifi firmware crash, reloading..."
              ${pkgs.kmod}/bin/modprobe -r iwlmvm
              ${pkgs.kmod}/bin/modprobe -r iwlwifi
              sleep 3
              ${pkgs.kmod}/bin/modprobe iwlwifi
              sleep 5
              ${pkgs.networkmanager}/bin/nmcli device connect wlp61s0 || true
              echo "$(date): Driver reloaded" >> /var/log/wifi-crashes.log
              # Wait 60 seconds before monitoring again to avoid reload loops
              sleep 60
            fi
          done
        '';
      };
    };

    # NetworkManager configuration (only if NetworkManager is enabled)
    networking.networkmanager = mkIf (cfg.powerSaveDisable && config.networking.networkmanager.enable) {
      wifi.powersave = false;
    };

    # Automatic WiFi driver reload after suspend/resume
    systemd.services.wifi-resume-fix = mkIf cfg.enableResumefix {
      description = "Reload WiFi driver after resume";
      after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
      wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "wifi-resume-fix" ''
          # Wait for system to stabilize
          sleep 5

          # Check if WiFi is working
          if ! timeout 10 ${pkgs.iputils}/bin/ping -c 1 ${cfg.gateway} >/dev/null 2>&1; then
            echo "WiFi appears stuck after resume, reloading driver..."
            ${pkgs.kmod}/bin/modprobe -r ${cfg.driver}
            sleep 3
            ${pkgs.kmod}/bin/modprobe ${cfg.driver}
            sleep 5
            # Reconnect to WiFi
            ${optionalString cfg.networkManager "${pkgs.networkmanager}/bin/nmcli device connect ${cfg.interface} || true"}
          fi
        '';
      };
    };

    # WiFi watchdog service
    systemd.services.wifi-watchdog = mkIf cfg.enableWatchdog {
      description = "WiFi Watchdog - detects and fixes WiFi hangs";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "60";
        User = "root";
        ExecStart = pkgs.writeShellScript "wifi-watchdog" ''
          while true; do
            sleep ${toString cfg.watchdogInterval}

            # Check if we can reach the gateway
            if ! timeout 15 ${pkgs.iputils}/bin/ping -c 2 ${cfg.gateway} >/dev/null 2>&1; then
              # Check if WiFi interface exists and appears up
              if ${pkgs.iproute2}/bin/ip link show ${cfg.interface} 2>/dev/null | grep -q "state UP"; then
                echo "$(date): WiFi interface up but can't reach gateway, reloading driver..."

                # Reload the driver
                ${pkgs.kmod}/bin/modprobe -r ${cfg.driver}
                sleep 5
                ${pkgs.kmod}/bin/modprobe ${cfg.driver}
                sleep 10

                # Reconnect
                ${optionalString cfg.networkManager "${pkgs.networkmanager}/bin/nmcli device connect ${cfg.interface} || true"}

                # Log the event
                echo "$(date): WiFi driver reloaded for interface ${cfg.interface}" >> /var/log/wifi-watchdog.log
              fi
            fi
          done
        '';
      };
    };

    # udev rules to prevent power management issues
    services.udev.extraRules = mkIf cfg.powerSaveDisable ''
      # Keep Intel WiFi powered on (adjust device IDs as needed)
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x08b1", ATTR{power/control}="on"
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x08b2", ATTR{power/control}="on"
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x095a", ATTR{power/control}="on"
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x095b", ATTR{power/control}="on"

      # Disable power saving on WiFi interface when it comes up
      ACTION=="add", SUBSYSTEM=="net", KERNEL=="${cfg.interface}", RUN+="${pkgs.iw}/bin/iw dev ${cfg.interface} set power_save off"
    '';

    # Create a system-wide WiFi fix script
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "fix-wifi" ''
        #!/usr/bin/env bash
        # WiFi Fix Script

        echo "=== WiFi Fix Script ==="
        echo "Checking WiFi status for interface ${cfg.interface}..."

        # Check if interface exists
        if ! ${pkgs.iproute2}/bin/ip link show ${cfg.interface} >/dev/null 2>&1; then
            echo "WiFi interface ${cfg.interface} not found!"
            echo "Available interfaces:"
            ${pkgs.iproute2}/bin/ip link show | grep -E '^[0-9]+:' | cut -d: -f2 | tr -d ' '
            exit 1
        fi

        # Check if we can ping gateway
        if timeout 10 ${pkgs.iputils}/bin/ping -c 2 ${cfg.gateway} >/dev/null 2>&1; then
            echo "WiFi is working fine!"
            exit 0
        fi

        echo "WiFi appears to be stuck. Reloading driver..."

        # Reload driver
        echo "Step 1: Unloading ${cfg.driver} driver..."
        if sudo ${pkgs.kmod}/bin/modprobe -r ${cfg.driver}; then
            echo "Driver unloaded successfully"
        else
            echo "Failed to unload driver"
            exit 1
        fi

        echo "Waiting 5 seconds..."
        sleep 5

        echo "Step 2: Loading ${cfg.driver} driver..."
        if sudo ${pkgs.kmod}/bin/modprobe ${cfg.driver}; then
            echo "Driver loaded successfully"
        else
            echo "Failed to load driver"
            exit 1
        fi

        echo "Waiting for interface to come up..."
        sleep 5

        # Check if interface is back
        if ${pkgs.iproute2}/bin/ip link show ${cfg.interface} >/dev/null 2>&1; then
            echo "Interface is back up"
        else
            echo "Interface still not available"
            exit 1
        fi

        # Reconnect to WiFi
        echo "Step 3: Reconnecting to WiFi..."
        ${optionalString cfg.networkManager "${pkgs.networkmanager}/bin/nmcli device connect ${cfg.interface}"}

        echo "Waiting for connection..."
        sleep 10

        # Test connectivity
        if timeout 10 ${pkgs.iputils}/bin/ping -c 2 ${cfg.gateway} >/dev/null 2>&1; then
            echo "✓ WiFi fix successful! Gateway is reachable."
            current_ip=$(${pkgs.iproute2}/bin/ip addr show ${cfg.interface} | grep 'inet ' | awk '{print $2}' | head -n1)
            echo "✓ Current IP: $current_ip"
        else
            echo "✗ Still having connectivity issues"
            echo "You may need to:"
            echo "1. Check if your WiFi password is correct"
            echo "2. Try moving closer to the router"
            echo "3. Restart your router"
            echo "4. Reboot your laptop as a last resort"
        fi
      '')
    ];
  };
}
