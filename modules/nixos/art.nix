{ config, lib, pkgs, ... }: {

    options = {
        blender = {
            enable = lib.mkEnableOption "enables blender";
        };
        gimp = {
            enable = lib.mkEnableOption "enables gimp";
        };
        godot = {
            enable = lib.mkEnableOption "enables godot";
        };
        inkscape = {
            enable = lib.mkEnableOption "enables inkscape";
        };
        krita = {
            enable = lib.mkEnableOption "enables krita";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.blender.enable {
          environment.systemPackages = with pkgs; [ (unstable.blender.override {cudaSupport=true;}) ];  #3D Creation/Animation/Publishing System
        })
        (lib.mkIf config.gimp.enable {
          environment.systemPackages = with pkgs; [ unstable.gimp-with-plugins ];  #GNU Image Manipulation Program
        })
        (lib.mkIf config.godot.enable {
          environment.systemPackages = with pkgs; [ unstable.godot_4 ];  #Free and Open Source 2D and 3D game engine
        })
        (lib.mkIf config.inkscape.enable {
          environment.systemPackages = with pkgs; [ unstable.inkscape-with-extensions ];  #Vector graphics editor
        })
        (lib.mkIf config.krita.enable {
          environment.systemPackages = with pkgs; [ unstable.krita ];  #Free and open source painting application
        })
    ];

}
