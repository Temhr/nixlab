{self, ...}: {
  flake.nixosModules.servc--wifi-hotspot-nixlab = {
    config,
    lib,
    pkgs,
    nixlabLib,
    ...
  }: let
    cfg = config.services.wifi-hotspot-nixlab;

    # Fixed system path NetworkManager reads keyfile-style connection
    # profiles from. Used in both the ExecStart script and the systemd
    # unit's writablePaths, so hoisted per §6.
    connectionFile = "/etc/NetworkManager/system-connections/hotspot-${cfg.interface}.nmconnection";
  in {
    # ============================================================================
    # OPTIONS - Define what can be configured
    # ============================================================================
    options = {
      services.wifi-hotspot-nixlab = {
        # REQUIRED: Enable the wifi hotspot service
        enable = lib.mkEnableOption "wifi access point / hotspot, shared from the host's ethernet uplink";

        # REQUIRED: Wifi radio to dedicate fully to AP mode
        interface = lib.mkOption {
          type = lib.types.str;
          example = "wlan0";
          description = ''
            Wifi radio to dedicate fully to AP mode. Only sensible when the
            host's internet comes from elsewhere (ethernet) — this radio
            will not act as a wifi client at the same time.
          '';
        };

        # OPTIONAL: Broadcast SSID (default: "<hostname>-hotspot")
        ssid = lib.mkOption {
          type = lib.types.str;
          default = "${config.networking.hostName}-hotspot";
          description = "Broadcast SSID. Not sensitive — visible to anyone in range regardless.";
        };

        # OPTIONAL: Wifi band (default: "bg" = 2.4GHz)
        band = lib.mkOption {
          type = lib.types.enum ["a" "bg"];
          default = "bg";
          description = ''
            Wifi band: "bg" for 2.4GHz, "a" for 5GHz. Every host surveyed so
            far (nixace, nixvat, nixtop, nixzen, nixsun) marks all 5GHz
            channels "(no IR)" in `iw list`, meaning the card is legally
            barred from transmitting an AP beacon there until it's
            passively detected a nearby AP first — in practice "a" won't
            come up on any of these radios.
          '';
        };

        # OPTIONAL: Fixed channel (default: null = auto)
        channel = lib.mkOption {
          type = lib.types.nullOr lib.types.port;
          default = null;
          description = ''
            Fixed channel, or null to let NetworkManager pick automatically.
            For "bg", stick to 1-11 — channels 12/13 are "(no IR)" on most
            of the surveyed hosts, and 14 is disabled everywhere.
          '';
        };

        # OPTIONAL: Hide the SSID from broadcast scans (default: false)
        hidden = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Hide the SSID from broadcast scans.";
        };

        # OPTIONAL: Bring the hotspot up automatically (default: true)
        autoconnect = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Bring the hotspot up automatically on boot/interface presence.";
        };

        # OPTIONAL: NetworkManager package providing nmcli (default: pkgs.networkmanager)
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.networkmanager;
          defaultText = lib.literalExpression "pkgs.networkmanager";
          description = "The NetworkManager package providing nmcli, used to reload the profile after rendering it.";
        };

        # OPTIONAL: Auto-open DNS/DHCP on the hotspot interface (default: true)
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open DNS (53) and DHCP (67) on the hotspot interface for connecting clients.";
        };

        # OPTIONAL: Trust hotspot clients to reach host services (default: false)
        trustInterface = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            If true, fully trusts traffic from hotspot clients (they can
            reach any service on the host) instead of just DNS/DHCP.
          '';
        };

        # OPTIONAL: sops-nix path to a file containing the plaintext hotspot password.
        passwordFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = "/run/secrets/wifi_hotspot_password";
          description = ''
            Path to a file whose sole content is the plaintext WPA-PSK
            password. When null, the service is enabled but cannot render
            a valid connection profile. A real value only ever comes from
            the paired nsops--wifi-hotspot module.
          '';
        };
      };
    };

    # ============================================================================
    # CONFIG
    # ============================================================================
    config = lib.mkIf cfg.enable {
      # ============================================================================
      # ASSERTIONS - Catch invalid option combinations at eval time
      # ============================================================================
      assertions = [
        {
          assertion = config.networking.networkmanager.enable;
          message = "services.wifi-hotspot-nixlab requires networking.networkmanager.enable = true (see hosts--core--networking).";
        }
        {
          assertion = cfg.passwordFile != null;
          message = "services.wifi-hotspot-nixlab.passwordFile is unset — import nsops--wifi-hotspot for this host, or set it directly.";
        }
        {
          assertion = cfg.band != "bg" || cfg.channel == null || (cfg.channel >= 1 && cfg.channel <= 11);
          message = "services.wifi-hotspot-nixlab: channel ${toString cfg.channel} is outside 1-11, the only range confirmed IR-clear across the fleet's 2.4GHz radios.";
        }
      ];

      warnings = lib.optional (cfg.band == "a") ''
        services.wifi-hotspot-nixlab on ${config.networking.hostName}: band "a" (5GHz) is
        set, but every surveyed host's radio marks all 5GHz channels "(no IR)" — this AP
        will likely fail to start transmitting. Verify with `iw list` on this host.
      '';

      # ----------------------------------------------------------------------------
      # WIFI-HOTSPOT SERVICE - renders + (re)applies the NM connection profile
      # ----------------------------------------------------------------------------
      systemd.services."wifi-hotspot-${cfg.interface}" = {
        description = "Render and apply NetworkManager hotspot profile for ${cfg.interface}";
        wantedBy = ["multi-user.target"];
        after = ["NetworkManager.service"];
        wants = ["NetworkManager.service"];

      serviceConfig =
        nixlabLib.mkServiceHardening {
          writablePaths = ["/etc/NetworkManager/system-connections"];
        }
        // {
          Type = "oneshot";
          RemainAfterExit = true;
          # nmcli talks to NetworkManager over the system D-Bus (AF_UNIX) and
          # reads interface state via rtnetlink (AF_NETLINK) — mkServiceHardening's
          # allowNetwork=true grant only covers AF_INET/AF_INET6, so both must be
          # restored explicitly or nmcli can't open a socket at all.
          RestrictAddressFamilies = ["AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6"];
          ExecStart = pkgs.writeShellScript "wifi-hotspot-${cfg.interface}-apply" ''
            set -euo pipefail
            install -d -m 0700 /etc/NetworkManager/system-connections
            psk="$(cat ${lib.escapeShellArg cfg.passwordFile})"
            umask 077
            cat > ${connectionFile} <<CONNEOF
            [connection]
            id=hotspot-${cfg.interface}
            type=wifi
            interface-name=${cfg.interface}
            autoconnect=${lib.boolToString cfg.autoconnect}

            [wifi]
            mode=ap
            ssid=${cfg.ssid}
            band=${cfg.band}
            ${lib.optionalString (cfg.channel != null) "channel=${toString cfg.channel}"}
            hidden=${lib.boolToString cfg.hidden}

            [wifi-security]
            key-mgmt=wpa-psk
            psk=$psk

            [ipv4]
            method=shared

            [ipv6]
            method=disabled
            CONNEOF
            chmod 600 ${connectionFile}
            ${cfg.package}/bin/nmcli connection reload
          '';
        };
      };

      # ----------------------------------------------------------------------------
      # FIREWALL - DNS/DHCP for hotspot clients on this interface only
      # ----------------------------------------------------------------------------
      networking.firewall.interfaces.${cfg.interface} = lib.mkIf cfg.openFirewall (
        if cfg.trustInterface
        then {allowedTCPPorts = lib.range 1 65535; allowedUDPPorts = lib.range 1 65535;}
        else {
          allowedUDPPorts = [53 67];
          allowedTCPPorts = [53];
        }
      );
    };
  };
}

/*
================================================================================
USAGE EXAMPLES
================================================================================

Minimal (per host — nixace, nixvat, nixtop, nixzen, nixsun all supported,
each a single-radio machine surveyed via `iw list`):
--------
services.wifi-hotspot-nixlab = {
  enable = true;
  interface = "wlan0";
};

Full configuration:
--------------------
services.wifi-hotspot-nixlab = {
  enable = true;
  interface = "wlan0";
  ssid = "nixace-hotspot";
  band = "bg";
  channel = 6;
  trustInterface = false;
};


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  systemctl status wifi-hotspot-wlan0

Stream live logs:
  journalctl -u wifi-hotspot-wlan0 -f

Check the rendered NM connection profile:
  cat /etc/NetworkManager/system-connections/hotspot-wlan0.nmconnection

Check AP status / connected clients:
  nmcli device show wlan0
  nmcli connection show hotspot-wlan0

Force a re-render after changing options:
  systemctl restart wifi-hotspot-wlan0
*/
