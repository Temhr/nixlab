{ config, lib, pkgs, ... }:

let
    myscript = pkgs.writeShellScript "MoveFiles.sh" ''
      cp /home/temhr/nixlab/bin/bash/.bash_profile /home
    '';
in

{
  systemd.services.MoveFiles = {
    description = "script write";
    serviceConfig ={
      ExecStart = myscript;
      Type = "oneshot";
      User = "root";
    };
    startAt = "*:0/2";
  };
}
