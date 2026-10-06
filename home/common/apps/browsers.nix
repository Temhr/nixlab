{...}: {
  flake.homeModules.home--apps--browsers = {
    config,
    lib,
    pkgs,
    inputs,
    ...
  }: let
    nasRoot = "/mnt/mirnixnas1/home/nixALL";
    link = config.lib.file.mkOutOfStoreSymlink;

    # Build home.file entries that symlink into a NAS directory.
    # target: dir under $HOME, source: dir on the NAS, files: relative paths
    nasLinks = target: source: files:
      lib.listToAttrs (map (f: {
          name = "${target}/${f}";
          value = {
            source = link "${source}/${f}";
            force = true; # replace existing files/dirs at the target
          };
        })
        files);
  in {
    options = {
      brave.enable = lib.mkEnableOption "enables Brave browser";
      chrome.enable = lib.mkEnableOption "enables Chrome browser";
      edge.enable = lib.mkEnableOption "enables Edge browser";
      zen.enable = lib.mkEnableOption "enables Zen browser";
      firefox.enable = lib.mkEnableOption "links Firefox profile files to the NAS (package is installed by the NixOS module)";
    };

    config = lib.mkMerge [
      (lib.mkIf config.brave.enable {
        home.packages = with pkgs; [brave];
      })
      (lib.mkIf config.chrome.enable {
        home.packages = with pkgs; [google-chrome];
      })
      (lib.mkIf config.edge.enable {
        home.packages = [pkgs.unstable.microsoft-edge];
      })
      (lib.mkIf config.zen.enable {
        home.packages = [inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta];
        home.file =
          nasLinks ".config/zen" "${nasRoot}/zen" ["profiles.ini"]
          // nasLinks ".config/zen/uni.default" "${nasRoot}/zen/uni.default" [
            "bookmarkbackups"
            "containers.json"
            "favicons.sqlite"
            "places.sqlite"
            "prefs.js"
          ];
      })
      (lib.mkIf config.firefox.enable {
        home.file =
          nasLinks ".config/mozilla/firefox" "${nasRoot}/mozilla/firefox" ["profiles.ini"]
          // nasLinks ".config/mozilla/firefox/uni.default" "${nasRoot}/mozilla/firefox/uni.default" [
            "bookmarkbackups"
            "containers.json"
            "favicons.sqlite"
            "places.sqlite"
            "prefs.js"
          ];
      })
    ];
  };
}
