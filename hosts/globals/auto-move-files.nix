{ config, lib, pkgs, ... }:

let
    myscript = pkgs.writeShellScript "MoveFiles.sh" ''
      mv /home/temhr/nixlab/bin/bash/* /home
    '';
in

{
  systemd.services.MoveFiles = {
    description = "script write";
    serviceConfig ={
      ExecStart = myscript;
      Type = "oneshot";
      User = "temhr";
    };
    startAt = "*:0/2";
  };
}
