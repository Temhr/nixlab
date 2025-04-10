{ config, lib, pkgs, ... }:{

    options = {
        anki = {
            enable = lib.mkEnableOption "enables Anki";
        };
        google-earth = {
            enable = lib.mkEnableOption "enables Google-Earth";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.anki.enable {
          home.packages = [ pkgs.unstable.anki-bin ];  #Spaced repetition flashcard program
        })
        (lib.mkIf config.google-earth.enable {
          home.packages = [ pkgs.unstable.googleearth-pro ];  #World sphere viewer
        })
    ];

}
