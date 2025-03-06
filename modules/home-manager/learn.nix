{ config, lib, pkgs, ... }:{

    options = {
        anki = {
            enable = lib.mkEnableOption "enables Anki";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.anki.enable {
          home.packages = [ pkgs.unstable.anki-bin ];  #Spaced repetition flashcard program
        })
    ];

}
