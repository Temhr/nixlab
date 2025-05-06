{ config, lib, ... }:

let
  cfg = config.GROUP;
in {
  options = {
    GROUP = {
      CHOICE = lib.mkOption {
        type = lib.types.enum [ "none" "ONE" "TWO" "THREE" ];
        default = "none";
        description = "Select which between three options or none";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.CHOICE == "ONE") {

    })
    (lib.mkIf (cfg.CHOICE == "TWO") {

    })
    (lib.mkIf (cfg.CHOICE == "THREE") {

    })
  ];
}

## Goes in config file
# Choose between these choices: "none" "ONE" "TWO" "THREE"
# GROUP.CHOICE = "TWO";
