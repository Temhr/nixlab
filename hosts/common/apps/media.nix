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
          enableVirtualCamera = false; # we declare v4l2loopback ourselves below
          plugins = with pkgs.obs-studio-plugins; [
            wlrobs
            obs-backgroundremoval
            obs-pipewire-audio-capture
          ];
        };

        # v4l2loopback, with the stray modules.* index files removed
        boot.extraModulePackages = [
          (config.boot.kernelPackages.v4l2loopback.overrideAttrs (old: {
            postInstall =
              (old.postInstall or "")
              + ''
                find $out/lib/modules -maxdepth 2 -name 'modules.*' -delete
              '';
          }))
        ];
        boot.kernelModules = ["v4l2loopback"];
        boot.extraModprobeConfig = ''
          options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
        '';

        # Ensure your user is in the video group
        users.users.${config.nixlab.mainUser} = {
          extraGroups = ["video"];
        };
      })
      (lib.mkIf config.spotify.enable {
        environment.systemPackages = with pkgs; [spotify]; # Play music from the Spotify music service
      })
      (lib.mkIf config.vlc.enable {
        environment.systemPackages = with pkgs; [vlc]; # Cross-platform media player and streaming server
      })
    ];
  };
}
