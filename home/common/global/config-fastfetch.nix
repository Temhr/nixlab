{...}: {
  programs.fastfetch.enable = true;
  programs.fastfetch.settings = {
    display = {
      size = {
        binaryPrefix = "si";
      };
      color = "blue";
      separator = " • ";
    };
    modules = [
      "title"
      "separator"
      "host"
      "os"
      "kernel"
      {
        "type" = "command";
        "key" = "OS Age";
        "text" = "birth_install=$(stat -c %W /); current=$(date +%s); days_difference=$(( (current - birth_install) / 86400 )); echo $days_difference days";
      }
      "uptime"
      "packages"
      "shell"
      "terminal"
      "editor"
      "loadavg"
      "processes"
      {
        "type" = "cpu";
        "showPeCoreCount" = true;
        "temp" = true;
      }
      "cpuusage"
      {
        "type" = "gpu";
        "driverSpecific" = true;
        "temp" = true;
      }
      "memory"
      "physicalmemory"
      "swap"
      "disk"
      "btrfs"
      "zpool"
      {
        "type" = "battery";
        "temp" = true;
      }
      "poweradapter"
      {
        "type" = "localip";
      }
      "datetime"
      {
        "type" = "weather";
        "timeout" = 1000;
      }
      "break"
      "colors"
    ];
  };
}
