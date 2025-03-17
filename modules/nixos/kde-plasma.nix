{ config, lib, pkgs, ... }: {

    options = {
        wallpaper = {
            enable = lib.mkEnableOption {
              description = "Enables blender";
              default = false;
            };
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.wallpaper.enable {

          systemd.user.services.set-wallpaper = {
            description = "Set KDE Plasma wallpaper";
            serviceConfig.ExecStart = [ "/run/current-system/sw/bin/plasma-apply-wallpaperimage /mnt/mirbase/Hard Drive Backup/Users/Effy/Pictures/Wallpapers/qwrHySG.jpg" ];
            wantedBy = [ "graphical-session.target" ];
          };

        })
    ];

}
