{ config, lib, pkgs, inputs, ... }: {

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
          home.packages = with pkgs; [ brave ];  #Privacy-oriented browser for Desktop and Laptop computerse
        })
        (lib.mkIf config.chrome.enable {
          home.packages = with pkgs; [ google-chrome ];  #Freeware web browser developed by Google
        })
        (lib.mkIf config.edge.enable {
          home.packages = with pkgs; [ unstable.microsoft-edge ];  #The web browser from Microsoft
        })
        (lib.mkIf config.zen.enable {
          home.packages = [ inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta ];  #
        })
    ];

}
