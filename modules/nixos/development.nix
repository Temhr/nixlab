{ config, lib, pkgs, ... }: {

    options = {
        conda = {
            enable = lib.mkEnableOption {
              description = "Enables conda";
              default = false;
            };
        };
        spyder = {
            enable = lib.mkEnableOption {
              description = "Enables spyder";
              default = false;
            };
        };
        vscode = {
            enable = lib.mkEnableOption {
              description = "Enables vscode";
              default = false;
            };
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.conda.enable {
            environment.systemPackages = with pkgs; [
                conda  #Package manager for Python
            ];
        })
        (lib.mkIf config.spyder.enable {
            environment.systemPackages = with pkgs; [
                spyder  #Scientific python development environment
            ];
        })
        (lib.mkIf config.vscode.enable {
            environment.systemPackages = with pkgs; [
                vscode #Open source source code editor developed by Microsoft
            ];
        })
    ];

}
