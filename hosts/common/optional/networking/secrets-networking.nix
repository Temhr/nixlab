{...}: {
  flake.nixosModules.secrets--networking = {...}: {
    sops.secrets.wifi_ssid = {sopsFile = ./networking.yaml;};
    sops.secrets.wifi_password = {sopsFile = ./networking.yaml;};
  };
}
