{ config, lib, pkgs, ... }: {

    options = {
        gnome = {
            enable = lib.mkEnableOption {
              description = "Enables Gnome";
              default = false;
            };
        };
        plasma = {
            enable = lib.mkEnableOption {
              description = "Enables KDE Plasma";
              default = false;
            };
        };
        sway = {
            enable = lib.mkEnableOption {
              description = "Enables Sway";
              default = false;
            };
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.gnome.enable {

            services.xserver = {
                enable = true;  #enables the X11 windowing system.
                displayManager.gdm.enable = true;
                desktopManager.gnome.enable = true;  #installs gnome
            };

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

            # Enable the gnome-keyring secrets vault.
            # Will be exposed through DBus to programs willing to store secrets.
            services.gnome.gnome-keyring.enable = true;
            # enable sway window manager
            programs.sway = {
                enable = true;
                wrapperFeatures.gtk = true; # so that gtk works properly
                extraPackages = with pkgs; [
                swaylock
                swayidle
                wl-clipboard  # wl-copy and wl-paste for copy/paste from stdin / stdout
                wf-recorder
                mako # notification daemon developed by swaywm maintainer
                grim # screenshot functionality
                #kanshi
                slurp # screenshot functionality
                alacritty # Alacritty is the default terminal in the config
                dmenu # Dmenu is the default in the config but i recommend wofi since its wayland native
                ];
                extraSessionCommands = ''
                export SDL_VIDEODRIVER=wayland
                export QT_QPA_PLATFORM=wayland
                export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
                export _JAVA_AWT_WM_NONREPARENTING=1
                export MOZ_ENABLE_WAYLAND=1
                '';
            };
            programs.waybar.enable = true;

        })
    ];

}
