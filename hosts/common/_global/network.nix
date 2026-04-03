# hosts/common/global/networking.nix
{ hostMeta, lib, ... }: {
  networking.useDHCP = false;
  networking.nameservers    = hostMeta.nameservers;
  networking.networkmanager.enable = true;
  networking.networkmanager.settings = {
    "connection"."wifi.powersave" = 2;
  };

  networking.networkmanager.ensureProfiles.profiles =
    lib.listToAttrs (map (iface: {
      name  = iface.name;
      value = {
        connection = {
          id   = iface.name;
          type = if lib.hasPrefix "wl" iface.name then "wifi" else "ethernet";
          interface-name = iface.name;
        };
        ipv4 = {
          method   = "manual";
          addresses = "${iface.address}/${toString hostMeta.prefixLength}";
          gateway  = hostMeta.gateway;
          dns      = lib.concatStringsSep ";" hostMeta.nameservers;
        };
        ipv6.method = "disabled";
      };
    }) hostMeta.interfaces);

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
}
