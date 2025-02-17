{ config, lib, pkgs, ... }: {

    options = {
        blender = {
            enable = lib.mkEnableOption "enables blender";
        };
        gimp = {
            enable = lib.mkEnableOption "enables gimp";
        };
        krita = {
            enable = lib.mkEnableOption "enables krita";
        };
        inkscape = {
            enable = lib.mkEnableOption "enables inkscape";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.blender.enable {
          environment.systemPackages = with pkgs; [ (blender.override {cudaSupport=true;}) ];  #3D Creation/Animation/Publishing System
        })
        (lib.mkIf config.gimp.enable {
          environment.systemPackages = with pkgs; [ unstable.gimp-with-plugin ];  #GNU Image Manipulation Program
        })
        (lib.mkIf config.krita.enable {
          environment.systemPackages = with pkgs; [ unstable.krita ];  #Free and open source painting application
        })
        (lib.mkIf config.inkscape.enable {
          environment.systemPackages = with pkgs; [ unstable.inkscape-with-extensions ];  #Vector graphics editor
        })
    ];

}
