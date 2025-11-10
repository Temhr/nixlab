{ config, lib, pkgs, ... }: {

    options = {
        anki = {
            enable = lib.mkEnableOption {
              description = "Enables anki";
              default = false;
            };
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.anki.enable {
            environment.systemPackages = with pkgs; [
                anki-bin  #Spaced repetition flashcard program
            ];
        })
    ];

}
