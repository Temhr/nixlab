{ config, lib, pkgs, ... }: {

    options = {
        alacritty = {
            enable = lib.mkEnableOption "enables alacritty";
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
          environment.systemPackages = [ pkgs.unstable.alacritty ];  #Cross-platform, GPU-accelerated terminal emulator
        })
        (lib.mkIf config.kitty.enable {
          environment.systemPackages = [ pkgs.unstable.kitty ];  #Modern, hackable, featureful, OpenGL based terminal emulator
        })
        (lib.mkIf config.konsole.enable {
          environment.systemPackages = [ pkgs.unstable.kdePackages.konsole ];  #Terminal emulator by KDE
        })
    ];

}
