{ config, lib, pkgs, ... }: {

    options = {
        audacity = {
            enable = lib.mkEnableOption {
              description = "Enables Audacity";
              default = false;
            };
        };
        kdenlive = {
            enable = lib.mkEnableOption {
              description = "Enables Kdenlive";
              default = false;
            };
        };
        obs = {
            enable = lib.mkEnableOption {
              description = "Enables OBS-studio";
              default = false;
            };
        };
        openshot = {
            enable = lib.mkEnableOption {
              description = "Enables Openshot";
              default = false;
            };
        };
        spotify = {
            enable = lib.mkEnableOption {
              description = "Enables Spotify";
              default = false;
            };
        };
        vlc = {
            enable = lib.mkEnableOption {
              description = "Enables VLC";
              default = false;
            };
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.audacity.enable {
          environment.systemPackages = [ pkgs.audacity ];  #Sound editor with graphical UI
        })
        (lib.mkIf config.kdenlive.enable {
          environment.systemPackages = [ pkgs.kdePackages.kdenlive ];  #Free and open source video editor, based on MLT Framework and KDE Frameworks
        })
        (lib.mkIf config.obs.enable {
            programs.obs-studio = {
                enable = true;  #Distributed version control system
                enableVirtualCamera = true;  #Installs and sets up the v4l2loopback kernel module, necessary for OBS to start a virtual camera.
            };
        })
        (lib.mkIf config.openshot.enable {
          environment.systemPackages = [ pkgs.openshot-qt ];  #Free, open-source video editor
        })
        (lib.mkIf config.spotify.enable {
          environment.systemPackages = [ pkgs.spotify ];  #Play music from the Spotify music service
        })
        (lib.mkIf config.vlc.enable {
          environment.systemPackages = [ pkgs.vlc ];  #Cross-platform media player and streaming server
        })
    ];

}
