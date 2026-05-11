{...}: {
  flake.nixosModules.nsops--networking = {...}: {
    sops.secrets.wifi_ssid = {
      sopsFile = ./networking.yaml;
      #owner = "root";
      #group = "root";
      #restartUnits = ["NetworkManager.service"];
    };
    sops.secrets.wifi_password = {
      sopsFile = ./networking.yaml;
      #owner = "root";
      #group = "root";
      #restartUnits = ["NetworkManager.service"];
    };
  };
}
