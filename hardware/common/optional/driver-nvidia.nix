{ config, lib, ... }:

let
  cfg = config.driver-nvidia;
in {
  options = {
    driver-nvidia = {
      quadro = lib.mkOption {
        type = lib.types.enum [ "none" "k" "p"];
        default = "none";
        description = "Select which between three options or none";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.quadro == "k") {
        hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
    })
    (lib.mkIf (cfg.quadro == "p") {
        hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.latest;
    })
  ];
}

## Goes in config file
# Choose between these choices: "none" "k" "p"
# driver-nvidia.quadro = "k";
