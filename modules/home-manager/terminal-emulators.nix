{ config, lib, pkgs, inputs, ... }: {

    options = {
        alacritty = {
            enable = lib.mkEnableOption "enables alacritty";
        };
        ghostty = {
            enable = lib.mkEnableOption "enables ghostty";
        };
        kitty = {
            enable = lib.mkEnableOption "enables kitty";
        };
        konsole = {
            enable = lib.mkEnableOption "enables konsole";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.alacritty.enable {
          home.packages = [ pkgs.alacritty ];  #Cross-platform, GPU-accelerated terminal emulator
        })
        (lib.mkIf config.ghostty.enable {
          home.packages = [ inputs.ghostty.packages.x86_64-linux.default ];  #fast, feature-rich, and cross-platform terminal emulator that uses platform-native UI and GPU acceleration
          #programs.ghostty.enable = true;
          programs.ghostty.settings = {
            theme = "Fahrenheit";
          };
        })
        (lib.mkIf config.kitty.enable {
          home.packages = [ pkgs.kitty ];  #Modern, hackable, featureful, OpenGL based terminal emulator
        })
        (lib.mkIf config.konsole.enable {
          home.packages = [ pkgs.kdePackages.konsole ];  #Terminal emulator by KDE
        })
    ];

}
