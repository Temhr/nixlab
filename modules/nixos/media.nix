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
          # Enable v4l2loopback kernel module for OBS virtual camera
          boot.extraModulePackages = with config.boot.kernelPackages; [
            v4l2loopback
          ];

          # Load the module at boot with proper parameters
          boot.extraModprobeConfig = ''
            options v4l2loopback devices=1 video_nr=10 card_label="OBS Cam" exclusive_caps=1
          '';

          # Alternative: Load module on demand
          boot.kernelModules = [ "v4l2loopback" ];

          # Ensure your user is in the video group
          users.users."temhr" = {
            extraGroups = [ "video" ];
          };

          # Install OBS with virtual camera support
          environment.systemPackages = with pkgs; [
            obs-studio
            v4l-utils  # Useful for debugging video devices
            (pkgs.wrapOBS {
                plugins = with pkgs.obs-studio-plugins; [
                  wlrobs
                  obs-backgroundremoval
                  obs-pipewire-audio-capture
                ];
            })
          ];
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
