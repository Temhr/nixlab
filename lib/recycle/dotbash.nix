{ config, lib, pkgs, ... }:
let
  bashrc = pkgs.writeShellScript "bashrc" ( builtins.readFile ../../bin/.bashrc );
  bash_profile  = pkgs.writeShellScript "bash_profile " ( builtins.readFile ../../bin/.bash_profile );
  bashrc = pkgs.writeShellScript "bashrc" ( builtins.readFile ../../bin/.bash/bash_aliases );
  bashrc = pkgs.writeShellScript "bashrc" ( builtins.readFile ../../bin/.bashrc );
in
{
    options = {
        brave = {
            enable = lib.mkEnableOption "enables Brave browser";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.brave.enable {
          home.packages = [ pkgs.brave ];  #Privacy-oriented browser for Desktop and Laptop computerse
        })
    ];

}
