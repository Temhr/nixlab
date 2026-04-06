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
  }: {
    inherit address system gateway prefixLength nameservers services;
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
    services = ["glance" "grafana" "prometheus" "loki" "comfyui" "ollama-gpu"];
  };
  nixsun = mkHostMeta {
    address = "192.168.0.203";
    ethIface = "enp0s25";
    wifiIface = "wlo1";
    services = ["glance" "grafana" "prometheus" "loki"];
  };
  nixtop = mkHostMeta {
    address = "192.168.0.202";
    ethIface = "enp0s25";
    wifiIface = "wlp61s0";
    services = ["glance" "grafana" "prometheus" "loki"];
  };
  nixvat = mkHostMeta {
    address = "192.168.0.201";
    ethIface = "enp0s25";
    wifiIface = "wlo1";
    services = ["glance" "grafana" "prometheus" "loki" "ollama-cpu" "syncthing-nixvat" "wikijs" "zola"];
  };
  nixzen = mkHostMeta {
    address = "192.168.0.204";
    ethIface = "enp0s25";
    wifiIface = "wlp61s0";
    services = ["glance" "grafana" "prometheus" "loki" "syncthing-nixzen"];
  };
}
