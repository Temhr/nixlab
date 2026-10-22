{...}: {
  flake.nixosModules.hosts--apps--media = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options = {
      obs = {
        enable = lib.mkEnableOption {
          description = "Enables OBS-studio";
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
      (lib.mkIf config.obs.enable {
        programs.obs-studio = {
          enable = true;

          enableVirtualCamera = false; # Sets up v4l2loopback kernel module for virtual camera
          boot.extraModulePackages = [
           (config.boot.kernelPackages.v4l2loopback.overrideAttrs (old: {
             postInstall = (old.postInstall or "") + ''
               find $out/lib/modules -maxdepth 2 -name 'modules.*' -delete
             '';
           }))
          ];
          boot.kernelModules = ["v4l2loopback"];
          boot.extraModprobeConfig = ''
           options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
          '';

          plugins = with pkgs.obs-studio-plugins; [
            wlrobs
            obs-backgroundremoval
            obs-pipewire-audio-capture
          ];
        };


        # Ensure your user is in the video group
        users.users.${config.nixlab.mainUser} = {
          extraGroups = ["video"];
        };
      })
      (lib.mkIf config.spotify.enable {
        environment.systemPackages = with pkgs; [spotify]; #Play music from the Spotify music service
      })
      (lib.mkIf config.vlc.enable {
        environment.systemPackages = with pkgs; [vlc]; #Cross-platform media player and streaming server
      })
    ];
  };
}
