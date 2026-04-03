{self, ...}: {
  flake.nixosModules.systm--networking = {
    hostMeta,
    lib,
    config,
    ...
  }: let
    ethernetIfaces = lib.filter (i: i.type == "ethernet") hostMeta.interfaces;
    wifiIfaces = lib.filter (i: i.type == "wifi") hostMeta.interfaces;

    mkEthernetProfile = iface: {
      name = iface.name;
      value = {
        connection = {
          id = iface.name;
          type = "ethernet";
          interface-name = iface.name;
        };
        ipv4 = {
          method = "manual";
          addresses = "${iface.address}/${toString hostMeta.prefixLength}";
          gateway = hostMeta.gateway;
          dns = lib.concatStringsSep ";" hostMeta.nameservers;
        };
        ipv6.method = "disabled";
      };
    };

    # Builds the keyfile content for a wifi interface.
    # sops.placeholder values are substituted at runtime before NM starts.
    mkWifiKeyfile = iface: ''
      [connection]
      id=${iface.name}
      type=wifi
      interface-name=${iface.name}

      [wifi]
      ssid=${config.sops.placeholder.wifi_ssid}
      mode=infrastructure

      [wifi-security]
      key-mgmt=wpa-psk
      psk=${config.sops.placeholder.wifi_password}

      [ipv4]
      method=manual
      addresses=${iface.address}/${toString hostMeta.prefixLength}
      gateway=${hostMeta.gateway}
      dns=${lib.concatStringsSep ";" hostMeta.nameservers}

      [ipv6]
      method=disabled
    '';
  in {
    imports = [
      self.nixosModules.secrets--networking
    ];
    networking.useDHCP = false;
    networking.nameservers = hostMeta.nameservers;
    networking.networkmanager.enable = true;
    networking.networkmanager.settings = {
      "connection"."wifi.powersave" = 2;
    };

    # Ethernet profiles via ensureProfiles (no secrets needed)
    networking.networkmanager.ensureProfiles.profiles =
      lib.listToAttrs (map mkEthernetProfile ethernetIfaces);

    # Wifi profiles via sops templates (secrets substituted at runtime)
    sops.templates = lib.listToAttrs (map (iface: {
        name = "nm-wifi-${iface.name}";
        value = {
          content = mkWifiKeyfile iface;
          path = "/etc/NetworkManager/system-connections/${iface.name}.nmconnection";
          mode = "0600"; # NM refuses keyfiles that are group/world readable
        };
      })
      wifiIfaces);

    networking.firewall = {
      enable = true;
      extraInputRules = ''
        ip saddr 192.168.0.0/24 accept
      '';
    };

    boot.extraModprobeConfig = ''
      options iwlwifi power_save=0
      options cfg80211 ieee80211_default_ps=0
    '';
  };
}
