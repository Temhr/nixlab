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
        vscodium = {
            enable = lib.mkEnableOption {
              description = "Enables vscodium";
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
        (lib.mkIf config.vscodium.enable {
            environment.systemPackages = with pkgs; [
                vscodium #VS Code without MS branding/telemetry/licensing
            ];
        })
    ];

}
