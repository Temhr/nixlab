{...}: {
  flake.homeModules.home--core--config-fastfetch = {...}: {
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
        "kernel"
        "os"
        "InitSystem"
        {
          "type" = "command";
          "key" = "OS Age";
          "text" = "birth_install=$(stat -c %W /); current=$(date +%s); days_difference=$(( (current - birth_install) / 86400 )); echo $days_difference days";
        }
        {
          "type" = "command";
          "key" = "Generation";
          "text" = "readlink /nix/var/nix/profiles/system | cut -d- -f2 | sed 's/^/#/'";
        }
        "uptime"

        "break"
        "shell"
        "terminal"
        "packages"
        "processes"
        "cpuusage"
        {
          "type" = "cpu";
          "showPeCoreCount" = true;
          "temp" = true;
        }
        {
          "type" = "gpu";
          "driverSpecific" = true;
          "temp" = true;
          "hideType" = "integrated";
        }
        "memory"
        "physicalmemory"
        "disk"
        "btrfs"
        "zpool"
        {
          "type" = "battery";
          "temp" = true;
        }

        "break"
        {
          "type" = "localip";
        }
        "datetime"
        {
          "type" = "weather";
          "location" = "Ottawa";
          "timeout" = 1000;
        }
        "colors"
      ];
    };
  };
}
