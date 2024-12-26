{ config, lib, ... }: {

  options.plasma = {
    enable = lib.mkEnableOption "enables Plasma";
  };

  config = lib.mkIf config.plasma.enable {

    ## Enable the X11 windowing system.
    services.xserver.enable = true;

    ## Enable Plasma6
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;   #enables wayland as default
    services.desktopManager.plasma6.enable = true;

  };

}
