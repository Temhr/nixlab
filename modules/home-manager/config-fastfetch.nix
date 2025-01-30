{ config, lib, pkgs, ... }:{

  programs.fastfetch.enable = true;
  programs.fastfetch.settings = {
    logo = {
      source = "nixos_small";
      padding = {
        right = 1;
      };
    };
    display = {
      size = {
        binaryPrefix = "si";
      };
      color = "blue";
      separator = "  ";
    };
    modules = [
      "title",
      "separator",
      "os",
      "host",
      "kernel",
      "initsystem",
      "uptime",
      "loadavg",
      "processes",
      "packages",
      "shell",
      "editor",
      "display",
      "lm",
      "de",
      "wm",
      "theme",
      "terminal",
      {
          "type": "cpu",
          "showPeCoreCount": true,
          "temp": true
      },
      "cpuusage",
      {
          "type": "gpu",
          "driverSpecific": true,
          "temp": true
      },
      "memory",
      "physicalmemory",
      "swap",
      "disk",
      "btrfs",
      "zpool",
      {
          "type": "battery",
          "temp": true
      },
      "poweradapter",
      {
          "type": "localip",
      },
      "datetime",
      {
        "type": "weather",
        "timeout": 1000
      },
      "break",
      "colors"
    ];
  };
}
