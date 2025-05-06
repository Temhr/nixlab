{ config, lib, ... }:

let
  cfg = config.nameSubject;
in {
  options = {
    nameSubject = {
      nameChoice = lib.mkOption {
        type = lib.types.enum [ "none" "one" "two" "three" ];
        default = "none";
        description = "Select which between three options or none";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.nameChoice == "one") {

    })
    (lib.mkIf (cfg.nameChoice == "two") {

    })
    (lib.mkIf (cfg.nameChoice == "three") {

    })
  ];
}

##Goes in config file
# Choose between "none" "one" "two" "three"
# nameSubject.nameChoice = "two";
