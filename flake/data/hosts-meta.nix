{self, ...}: let
  inherit (self.lib) mkHostMeta;
in {
  flake.lib.hostsMeta = {
    nixnas1 = mkHostMeta {
      address = "10.0.0.251";
      ethIface = "eno1";
      wifiIface = "";
      hostId = "c6e98cd9";
      nixpkgsInput = "nixpkgs-stable";
      homeUsers = ["temhr"];
      systemUsers = ["temhr" "guest"];
      primaryUser = "temhr";
    };
    nixnas2 = mkHostMeta {
      address = "10.0.0.252";
      ethIface = "eno1";
      wifiIface = "wlp1s0";
      hostId = "23d031fa";
      nixpkgsInput = "nixpkgs-stable";
      homeUsers = ["temhr"];
      systemUsers = ["temhr" "guest"];
      primaryUser = "temhr";
    };
    nixace = mkHostMeta {
      address = "10.0.0.200";
      ethIface = "enp0s31f6";
      wifiIface = "wlp3s0";
      hostId = "dbacbbff";
      nixpkgsInput = "nixpkgs-unstable";
      homeUsers = ["temhr"];
      systemUsers = ["temhr" "guest"];
      primaryUser = "temhr";
    };
    nixsun = mkHostMeta {
      address = "10.0.0.201";
      ethIface = "enp0s25";
      wifiIface = "wlo1";
      hostId = "eba785f1";
      nixpkgsInput = "nixpkgs-unstable";
      homeUsers = ["temhr"];
      systemUsers = ["temhr" "guest"];
      primaryUser = "temhr";
    };
    nixtop = mkHostMeta {
      address = "10.0.0.202";
      ethIface = "enp0s25";
      wifiIface = "wlp61s0";
      hostId = "4a313e3b";
      nixpkgsInput = "nixpkgs-unstable";
      homeUsers = ["temhr"];
      systemUsers = ["temhr" "guest"];
      primaryUser = "temhr";
    };
    nixvat = mkHostMeta {
      address = "10.0.0.203";
      ethIface = "enp0s25";
      wifiIface = "wlo1";
      hostId = "5845aa8d";
      nixpkgsInput = "nixpkgs-unstable";
      homeUsers = ["temhr"];
      systemUsers = ["temhr" "guest"];
      primaryUser = "temhr";
    };
    nixzen = mkHostMeta {
      address = "10.0.0.204";
      ethIface = "enp0s25";
      wifiIface = "wlp61s0";
      hostId = "9efcecaf";
      nixpkgsInput = "nixpkgs-unstable";
      homeUsers = ["temhr"];
      systemUsers = ["temhr" "guest"];
      primaryUser = "temhr";
    };
  };
}
