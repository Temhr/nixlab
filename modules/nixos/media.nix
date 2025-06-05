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
        media-downloader = {
            enable = lib.mkEnableOption {
              description = "Enables Media-Downloader";
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
          environment.systemPackages = with pkgs; [ audacity ];  #Sound editor with graphical UI
        })
        (lib.mkIf config.kdenlive.enable {
          environment.systemPackages = with pkgs; [ kdePackages.kdenlive ];  #Free and open source video editor, based on MLT Framework and KDE Frameworks
        })
        (lib.mkIf config.media-downloader.enable {
          environment.systemPackages = with pkgs; [ media-downloader ];  #Qt/C++ GUI front end for yt-dlp and others
        })
        (lib.mkIf config.obs.enable {
            programs.obs-studio = {
                enable = true;  #Distributed version control system
                enableVirtualCamera = true;  #Installs and sets up the v4l2loopback kernel module, necessary for OBS to start a virtual camera.
            };
            boot.extraModulePackages = with config.boot.kernelPackages; [
              v4l2loopback
            ];
            boot.kernelModules = [ "v4l2loopback" ];
            boot.extraModprobeConfig = ''
              options v4l2loopback devices=2 video_nr=1,2 card_label="OBS Cam, Virt Cam" exclusive_caps=1
            '';
            security.polkit.enable = true;
        })
        (lib.mkIf config.openshot.enable {
          environment.systemPackages = with pkgs; [ openshot-qt ];  #Free, open-source video editor
        })
        (lib.mkIf config.spotify.enable {
          environment.systemPackages = with pkgs; [ spotify ];  #Play music from the Spotify music service
        })
        (lib.mkIf config.vlc.enable {
          environment.systemPackages = with pkgs; [ vlc ];  #Cross-platform media player and streaming server
        })
    ];

}
