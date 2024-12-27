{ config, lib, pkgs, ... }:{

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
        vivaldi = {
            enable = lib.mkEnableOption "enables Vivaldi browser";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.brave.enable {
          home.packages = [ pkgs.brave ];  #Privacy-oriented browser for Desktop and Laptop computerse
        })
        (lib.mkIf config.chrome.enable {
          home.packages = [ pkgs.google-chrome ];  #The web browser from Microsoft
        })
        (lib.mkIf config.edge.enable {
          home.packages = [ pkgs.microsoft-edge ];  #Freeware web browser developed by Google
        })
        (lib.mkIf config.vivaldi.enable {
          home.packages = [ pkgs.vivaldi ];  #A Browser for our Friends, powerful and personal
        })
    ];

}
