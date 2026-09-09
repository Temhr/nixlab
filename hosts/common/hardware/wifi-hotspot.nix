# hosts/common/apps/wifi-hotspot.nix
{...}: {
  flake.nixosModules.hosts--hardware--wifi-hotspot = {
    config,
    lib,
    ...
  }: let
    cfg = config.nixlab.wifiHotspot;
  in {
    options.nixlab.wifiHotspot = {
      enable = lib.mkEnableOption "wifi access point / hotspot, shared from the host's ethernet uplink";

      interface = lib.mkOption {
        type = lib.types.str;
        example = "wlan0";
        description = ''
          Wifi radio to dedicate fully to AP mode. Only sensible when the
          host's internet comes from elsewhere (ethernet) — this radio will
          not act as a wifi client at the same time.
        '';
      };

      ssid = lib.mkOption {
        type = lib.types.str;
        default = "${config.networking.hostName}-hotspot";
        description = "Broadcast SSID. Not sensitive — visible to anyone in range regardless.";
      };

      band = lib.mkOption {
        type = lib.types.enum ["a" "bg"];
        default = "bg";
        description = ''
          Wifi band: "bg" for 2.4GHz, "a" for 5GHz. Every host surveyed so
          far (nixace, nixvat, nixtop, nixzen, nixsun) marks all 5GHz
          channels "(no IR)" in `iw list`, meaning the card is legally
          barred from transmitting an AP beacon there until it's passively
          detected a nearby AP first — in practice "a" won't come up on any
          of these radios. Only set "a" if you've confirmed a specific host
          has an unlocked 5GHz regulatory domain.
        '';
      };

      channel = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = ''
          Fixed channel, or null to let NetworkManager pick automatically.
          For "bg", stick to 1-11 — channels 12/13 are "(no IR)" on most of
          the surveyed hosts (nixace, nixvat, nixzen), and 14 is disabled
          everywhere.
        '';
      };

      hidden = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      autoconnect = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Bring the hotspot up automatically on boot/interface presence.";
      };

      trustInterface = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          If true, fully trusts traffic from hotspot clients (they can reach
          any service on the host). If false (default), only DHCP/DNS are
          opened on this interface, so hotspot clients get internet sharing
          but not access to the host's own services.
        '';
      };

      secretsFile = lib.mkOption {
        type = lib.types.path;
        default = ./secrets/wifi-hotspot-${config.networking.hostName}.yaml;
        description = ''
          sops file containing wifi_hotspot_password. Defaults to a
          per-hostname path so enabling this on multiple hosts doesn't
          silently share one password/file unless you explicitly point
          two hosts at the same file.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.networking.networkmanager.enable;
          message = "nixlab.wifiHotspot requires networking.networkmanager.enable = true (see hosts--core--networking).";
        }
        {
          assertion = cfg.band != "bg" || cfg.channel == null || (cfg.channel >= 1 && cfg.channel <= 11);
          message = "nixlab.wifiHotspot: channel ${toString cfg.channel} is outside 1-11, which is the only range confirmed IR-clear across the fleet's 2.4GHz radios.";
        }
      ];

      warnings = lib.optional (cfg.band == "a") ''
        nixlab.wifiHotspot on ${config.networking.hostName}: band "a" (5GHz) is set,
        but every surveyed host's radio marks all 5GHz channels "(no IR)" — this AP
        will likely fail to start transmitting. Verify with `iw list` on this host.
      '';

      sops.secrets."wifi_hotspot_password" = {
        sopsFile = cfg.secretsFile;
      };

      # Rendered at activation time via sops-nix template substitution — the
      # password never touches the Nix store; only the final file (root-owned,
      # 0600) on disk holds the plaintext, same pattern as the client wifi
      # profiles in hosts--core--networking.
      sops.templates."nm-hotspot-${cfg.interface}" = {
        content = ''
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
          psk=${config.sops.placeholder.wifi_hotspot_password}

          [ipv4]
          method=shared

          [ipv6]
          method=disabled
        '';
        path = "/etc/NetworkManager/system-connections/hotspot-${cfg.interface}.nmconnection";
        mode = "0600";
      };

      networking.firewall.interfaces.${cfg.interface} =
        if cfg.trustInterface
        then {allowedTCPPorts = lib.range 1 65535; allowedUDPPorts = lib.range 1 65535;}
        else {
          allowedUDPPorts = [53 67]; # DNS + DHCP for hotspot clients
          allowedTCPPorts = [53];
        };
    };
  };
}
