{ config, lib, pkgs, ... }: {

    options = {
        anki = {
            enable = lib.mkEnableOption {
              description = "Enables anki";
              default = false;
            };
        };
        google-earth = {
            enable = lib.mkEnableOption {
              description = "Enables google Earth Pro";
              default = false;
            };
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.anki.enable {
            environment.systemPackages = with pkgs; [
                unstable.anki-bin  #Spaced repetition flashcard program
            ];
        })
        (lib.mkIf config.google-earth.enable {
            environment.systemPackages = with pkgs; [
                unstable.googleearth-pro #World sphere viewer
            ];
        })
    ];

}
