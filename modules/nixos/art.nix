{ config, lib, pkgs, ... }: {

    options = {
        blender = {
            enable = lib.mkEnableOption {
              description = "Enables blender";
              default = false;
            };
        };
        gimp = {
            enable = lib.mkEnableOption {
              description = "Enables gimp";
              default = false;
            };
        };
        godot = {
            enable = lib.mkEnableOption {
              description = "Enables godot";
              default = false;
            };
        };
        inkscape = {
            enable = lib.mkEnableOption {
              description = "Enables inkscape";
              default = false;
            };
        };
        krita = {
            enable = lib.mkEnableOption {
              description = "Enables krita";
              default = false;
            };
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
          environment.systemPackages = with pkgs; [ unstable.godot_4 unstable.godot-export-templates];  #Free and Open Source 2D and 3D game engine
        })
        (lib.mkIf config.inkscape.enable {
          environment.systemPackages = with pkgs; [ unstable.inkscape-with-extensions ];  #Vector graphics editor
        })
        (lib.mkIf config.krita.enable {
          environment.systemPackages = with pkgs; [ unstable.krita ];  #Free and open source painting application
        })
    ];

}
