{ config, lib, pkgs, ... }: {

    options = {
        blender = {
            enable = lib.mkEnableOption {
              description = "Enables blender";
              default = false;
            };
        };
        darktable = {
            enable = lib.mkEnableOption {
              description = "Enables darktable";
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
          environment.systemPackages = with pkgs; [          #3D Creation/Animation/Publishing System
            (blender.override {cudaSupport=true;})   #Explicit CUDA support, but long compile time
          ];
        })
        (lib.mkIf config.darktable.enable {
          environment.systemPackages = with pkgs; [ darktable ];  #Virtual lighttable and darkroom for photographers
        })
        (lib.mkIf config.gimp.enable {
          environment.systemPackages = with pkgs; [ gimp3-with-plugins ];  #GNU Image Manipulation Program
        })
        (lib.mkIf config.godot.enable {
          environment.systemPackages = with pkgs; [ godot godot-export-templates];  #Free and Open Source 2D and 3D game engine
        })
        (lib.mkIf config.inkscape.enable {
          environment.systemPackages = with pkgs; [ inkscape-with-extensions ];  #Vector graphics editor
        })
        (lib.mkIf config.krita.enable {
          environment.systemPackages = with pkgs; [ krita ];  #Free and open source painting application
        })
    ];

}
