{ config, lib, ... }: {

    options = {
        gnome = {
            enable = lib.mkEnableOption "enables Gnome";
        };
        plasma = {
            enable = lib.mkEnableOption "enables KDE Plasma";
        };
        sway = {
            enable = lib.mkEnableOption "enables Sway";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.gnome.enable {

            services.xserver = {
                enable = true;  #enables the X11 windowing system.
                displayManager.gdm.enable = true;
                desktopManager.gnome.enable = true;  #installs gnome
            }

        })
        (lib.mkIf config.plasma.enable {

            ## Enable the X11 windowing system.
            services.xserver.enable = true;

            ## Enable Plasma6
            services.displayManager.sddm.enable = true;
            services.displayManager.sddm.wayland.enable = true;   #enables wayland as default
            services.desktopManager.plasma6.enable = true;  #installs plasma 6

        })
        (lib.mkIf config.sway.enable {

            environment.systemPackages = with pkgs; [
                grim # screenshot functionality
                slurp # screenshot functionality
                wl-clipboard # wl-copy and wl-paste for copy/paste from stdin / stdout
                mako # notification system developed by swaywm maintainer
            ];

            # Enable the gnome-keyring secrets vault.
            # Will be exposed through DBus to programs willing to store secrets.
            services.gnome.gnome-keyring.enable = true;

            # enable sway window manager
            programs.sway = {
                enable = true;
                wrapperFeatures.gtk = true;
            };

        })
    ];

}
