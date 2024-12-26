{ config, lib, ... }: {

    options = {
        plasma = {
            enable = lib.mkEnableOption "enables KDE Plasma";
        };
        sway = {
            enable = lib.mkEnableOption "enables sway";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.plasma.enable {

          ## Enable the X11 windowing system.
          services.xserver.enable = true;

          ## Enable Plasma6
          services.displayManager.sddm.enable = true;
          services.displayManager.sddm.wayland.enable = true;   #enables wayland as default
          services.desktopManager.plasma6.enable = true;

        })
        (lib.mkIf config.sway.enable {

        })
    ];

}
