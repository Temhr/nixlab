{lib, ...}: let
  mkHostMeta = {
    address,
    ethIface,
    wifiIface,
    system ? "x86_64-linux",
    gateway ? "10.0.0.1",
    prefixLength ? 24,
    nameservers ? ["9.9.9.9" "1.1.1.1"],
    hostId ? null,
    nixpkgsInput ? "nixpkgs", # defaults to stable
    homeUsers ? [], # usernames from usersMeta that get a home-manager profile on this host
  }: {
    inherit address system gateway prefixLength nameservers hostId nixpkgsInput homeUsers;
    interfaces =
      [
        {
          name = ethIface;
          inherit address;
          type = "ethernet";
        }
      ]
      ++ lib.optionals (wifiIface != "") [
        {
          name = wifiIface;
          inherit address;
          type = "wifi";
        }
      ];
  };
in {
  flake.lib.hostsMeta = {
    nixnas1 = mkHostMeta {
      address = "10.0.0.251";
      ethIface = "eno1";
      wifiIface = "";
      hostId = "c6e98cd9";
      nixpkgsInput = "nixpkgs-stable";
      homeUsers = ["temhr"];
    };
    nixnas2 = mkHostMeta {
      address = "10.0.0.252";
      ethIface = "eno1";
      wifiIface = "wlp1s0";
      hostId = "23d031fa";
      nixpkgsInput = "nixpkgs-stable";
      homeUsers = ["temhr"];
    };
    nixace = mkHostMeta {
      address = "10.0.0.200";
      ethIface = "enp0s31f6";
      wifiIface = "wlp3s0";
      hostId = "dbacbbff";
      nixpkgsInput = "nixpkgs-unstable";
      homeUsers = ["temhr"];
    };
    nixsun = mkHostMeta {
      address = "10.0.0.201";
      ethIface = "enp0s25";
      wifiIface = "wlo1";
      hostId = "eba785f1";
      nixpkgsInput = "nixpkgs-unstable";
      homeUsers = ["temhr"];
    };
    nixtop = mkHostMeta {
      address = "10.0.0.202";
      ethIface = "enp0s25";
      wifiIface = "wlp61s0";
      hostId = "4a313e3b";
      nixpkgsInput = "nixpkgs-unstable";
      homeUsers = ["temhr"];
    };
    nixvat = mkHostMeta {
      address = "10.0.0.203";
      ethIface = "enp0s25";
      wifiIface = "wlo1";
      hostId = "5845aa8d";
      nixpkgsInput = "nixpkgs-unstable";
      homeUsers = ["temhr"];
    };
    nixzen = mkHostMeta {
      address = "10.0.0.204";
      ethIface = "enp0s25";
      wifiIface = "wlp61s0";
      hostId = "9efcecaf";
      nixpkgsInput = "nixpkgs-unstable";
      homeUsers = ["temhr"];
    };
  };
}
