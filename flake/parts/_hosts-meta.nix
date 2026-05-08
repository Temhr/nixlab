let
  mkHostMeta = {
    address,
    ethIface,
    wifiIface,
    services,
    system ? "x86_64-linux",
    gateway ? "192.168.0.1",
    prefixLength ? 24,
    nameservers ? ["1.1.1.1" "9.9.9.9"],
    hostId ? null,
    nixpkgsInput ? "nixpkgs", # defaults to stable
  }: {
    inherit address system gateway prefixLength nameservers services hostId nixpkgsInput;
    interfaces = [
      {
        name = ethIface;
        inherit address;
        type = "ethernet";
      }
      {
        name = wifiIface;
        inherit address;
        type = "wifi";
      }
    ];
  };
in {
  nixace = mkHostMeta {
    address = "192.168.0.200";
    ethIface = "enp0s31f6";
    wifiIface = "wlp3s0";
    hostId = "dbacbbff";
    nixpkgsInput = "nixpkgs-stable";
    services = ["glance" "grafana" "prometheus" "loki" "bookstack" "comfyui" "ollama-gpu" "home-assistant"];
  };
  nixnas1 = mkHostMeta {
    address = "192.168.0.205";
    ethIface = "eno1";
    wifiIface = "";
    hostId = "c6e98cd9";
    nixpkgsInput = "nixpkgs-unstable";
    services = ["glance" "grafana" "prometheus" "loki"];
  };
  nixnas2 = mkHostMeta {
    address = "192.168.0.206";
    ethIface = "eno1";
    wifiIface = "wlp1s0";
    hostId = "23d031fa";
    nixpkgsInput = "nixpkgs-stable";
    services = ["glance" "grafana" "prometheus" "loki"];
  };
  nixsun = mkHostMeta {
    address = "192.168.0.203";
    ethIface = "enp0s25";
    wifiIface = "wlo1";
    hostId = "eba785f1";
    nixpkgsInput = "nixpkgs-stable";
    services = ["glance" "grafana" "prometheus" "loki"];
  };
  nixtop = mkHostMeta {
    address = "192.168.0.202";
    ethIface = "enp0s25";
    wifiIface = "wlp61s0";
    hostId = "4a313e3b";
    nixpkgsInput = "nixpkgs-stable";
    services = ["glance" "grafana" "prometheus" "loki"];
  };
  nixvat = mkHostMeta {
    address = "192.168.0.201";
    ethIface = "enp0s25";
    wifiIface = "wlo1";
    hostId = "5845aa8d";
    nixpkgsInput = "nixpkgs-stable";
    services = ["glance" "grafana" "prometheus" "loki" "ollama-cpu" "syncthing-nixvat" "wikijs" "zola"];
  };
  nixzen = mkHostMeta {
    address = "192.168.0.204";
    ethIface = "enp0s25";
    wifiIface = "wlp61s0";
    hostId = "9efcecaf";
    nixpkgsInput = "nixpkgs-stable";
    services = ["glance" "grafana" "prometheus" "loki" "syncthing-nixzen"];
  };
}
