{ config, lib, pkgs, ... }: {

    options = {
        blender = {
            enable = lib.mkEnableOption {
              description = "Enables blender";
              default = false;
            };
        };
        godot = {
            enable = lib.mkEnableOption {
              description = "Enables godot";
              default = false;
            };
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.blender.enable {
          environment.systemPackages = with pkgs; [
            blender   #3D Creation/Animation/Publishing System
            #(blender.override {cudaSupport=true;})   #Explicit CUDA support, but long compile time
          ];
        })
        (lib.mkIf config.godot.enable {
          environment.systemPackages = with pkgs; [ godot godot-export-templates-bin];  #Free and Open Source 2D and 3D game engine
        })
    ];

}
