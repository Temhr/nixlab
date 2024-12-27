{ config, lib, pkgs, ... }: {

    options = {
        chrome = {
            enable = lib.mkEnableOption "enables Chrome browser";
        };
        firefox = {
            enable = lib.mkEnableOption "enables Firefox browser";
        };
        vivaldi = {
            enable = lib.mkEnableOption "enables Vivaldi browser";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.chrome.enable {
          home.packages = [ pkgs.google-chrome ];  #Freeware web browser developed by Google
        })
        (lib.mkIf config.firefox.enable {
          programs.firefox = {
            enable = true;
          };
        })
        (lib.mkIf config.vivaldi.enable {
          home.packages = [ pkgs.vivaldi ];  #A Browser for our Friends, powerful and personal
        })
    ];

}
