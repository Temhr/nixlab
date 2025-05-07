{ config, lib, pkgs, ... }: {

  options = {
      TOGGLE = {
          enable = lib.mkEnableOption "enables TOGGLE";
      };
  };

  config = lib.mkMerge [
    (lib.mkIf config.TOGGLE.enable {


    })
  ];
}
