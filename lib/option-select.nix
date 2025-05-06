{ config, lib, ... }:

let
  cfg = config.group;
in {
  options = {
    group = {
      choice = lib.mkOption {
        type = lib.types.enum [ "none" "one" "two" "three" ];
        default = "none";
        description = "Select which between three options or none";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.choice == "one") {

    })
    (lib.mkIf (cfg.choice == "two") {

    })
    (lib.mkIf (cfg.choice == "three") {

    })
  ];
}

## Goes in config file
# Choose between these choices: "none" "one" "two" "three"
# group.choice = "two";
