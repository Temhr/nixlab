{ config, lib, pkgs, ... }: {

    options = {
        vivaldi = {
            enable = lib.mkEnableOption "enables Vivaldi browser";
        };
        firefox = {
            enable = lib.mkEnableOption "enables Firefox browser";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.vivaldi.enable {
          home.packages = [ pkgs.vivaldi ];  #A Browser for our Friends, powerful and personal
        })
        (lib.mkIf config.firefox.enable {
          programs.firefox = {
            enable = true;
          };
        })
    ];

}
