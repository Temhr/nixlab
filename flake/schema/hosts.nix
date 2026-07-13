{lib, ...}: {
  flake.lib.mkHostMeta = {
    address,
    ethIface,
    wifiIface,
    system ? "x86_64-linux",
    gateway ? "10.0.0.1",
    prefixLength ? 24,
    nameservers ? ["9.9.9.9" "1.1.1.1"],
    hostId ? null,
    nixpkgsInput ? "nixpkgs",
    homeUsers ? [],
    systemUsers ? [],
    primaryUser ? null,
  }: {
    inherit address system gateway prefixLength nameservers hostId nixpkgsInput homeUsers systemUsers primaryUser;
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
}
