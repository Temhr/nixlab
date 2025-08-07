{ config, lib, ... }:

let
  cfg = config.gShells;
in {
  options = {
    gShells = {
      DE = lib.mkOption {
        type = lib.types.enum [ "none" "gnome" "plasma6" ];
        default = "none";
        description = "Select between two Desktop Environments or none";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.DE == "gnome") {

      services.xserver = {
          enable = true;  #enables the X11 windowing system.
          displayManager.gdm.enable = true;
          desktopManager.gnome.enable = true;  #installs gnome
      };

    })
    (lib.mkIf (cfg.DE == "plasma6") {

      ## Enable the X11 windowing system.
      services.xserver.enable = true;

      ## Enable Plasma6
      services.displayManager.sddm.enable = true;
      services.displayManager.sddm.wayland.enable = true;   #enables wayland as default
      services.desktopManager.plasma6.enable = true;  #installs plasma 6

      environment.plasma6.excludePackages = with pkgs.kdePackages; [
        plasma-browser-integration
        elisa
      ];

    })
  ];
}
