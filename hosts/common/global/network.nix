{ ... }: {

    # Enable NetworkManager (rename if you already enable it elsewhere)
    networking.networkmanager.enable = true;

    # Tell NM not to power-save Wi-Fi
    networking.networkmanager.settings = {
    "connection" = { "wifi.powersave" = 2; };   # 2 = disabled
    };

    # Force-disable chipset power save at the kernel level (works for iwlwifi, ath9k, etc.)
    boot.extraModprobeConfig = ''
    options iwlwifi power_save=0
    options cfg80211 ieee80211_default_ps=0
    '';

    # Allow Entire LAN Subnet
    networking.firewall = {
      enable = true;

      extraCommands = ''
        iptables -A INPUT -s 192.168.0.0/24 -j ACCEPT
        iptables -A OUTPUT -d 192.168.9.0/24 -j ACCEPT
      '';
    };
}
