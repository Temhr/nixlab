{...}: {
  flake.homeModules.home--apps--browsers = {
    config,
    lib,
    pkgs,
    inputs,
    ...
  }: {
    options = {
      brave = {
        enable = lib.mkEnableOption "enables Brave browser";
      };
      chrome = {
        enable = lib.mkEnableOption "enables Chrome browser";
      };
      edge = {
        enable = lib.mkEnableOption "enables Edge browser";
      };
      zen = {
        enable = lib.mkEnableOption "enables Zen browser";
      };
    };

    config = lib.mkMerge [
      (lib.mkIf config.brave.enable {
        home.packages = with pkgs; [brave]; #Privacy-oriented browser for Desktop and Laptop computerse
      })
      (lib.mkIf config.chrome.enable {
        home.packages = with pkgs; [google-chrome]; #Freeware web browser developed by Google
      })
      (lib.mkIf config.edge.enable {
        home.packages = [pkgs.unstable.microsoft-edge]; #The web browser from Microsoft
      })
      (lib.mkIf config.zen.enable (let
        nas = "/mnt/mirnixnas1/home/nixALL/.zen";
        link = config.lib.file.mkOutOfStoreSymlink;
        managed = path: {
          source = link "${nas}/${path}";
          force = true; # replace existing files/dirs at the target
        };
      in {
        home.packages = [inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta]; #
        home.file = {
          ".config/zen/profiles.ini"                     = managed "profiles.ini";
          ".config/zen/uni.default/bookmarkbackups"      = managed "uni.default/bookmarkbackups";
          ".config/zen/uni.default/containers.json"      = managed "uni.default/containers.json";
          ".config/zen/uni.default/favicons.sqlite"      = managed "uni.default/favicons.sqlite";
          ".config/zen/uni.default/places.sqlite"        = managed "uni.default/places.sqlite";
          ".config/zen/uni.default/prefs.js"             = managed "uni.default/prefs.js";
        };
      }))
    ];
  };
}
