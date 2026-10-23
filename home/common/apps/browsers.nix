{...}: {
  flake.homeModules.home--apps--browsers = {
    config,
    lib,
    pkgs,
    inputs,
    ...
  }: {
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
      })
      (lib.mkIf config.firefox.enable {})
    ];
  };
}
