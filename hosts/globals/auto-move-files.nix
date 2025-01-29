{ config, lib, pkgs, ... }:

let
    myscript = pkgs.writeShellScript "MoveFiles.sh" ''
       cp /home/temhr/nixlab/bin/bash/.bash_profile /home/temhr/.bash_profile &&
       cp /home/temhr/nixlab/bin/bash/.bashrc /home/temhr/.bashrc &&
       cp /home/temhr/nixlab/bin/bash/.bash/bash_aliases /home/temhr/.bash/bash_prompt &&
       cp /home/temhr/nixlab/bin/bash/.bash/bash_functions /home/temhr/.bash/bash_functions &&
       cp /home/temhr/nixlab/bin/bash/.bash/bash_prompt /home/temhr/.bash/bash_prompt
    '';
in

{
  systemd.services.MoveFiles = {
    description = "Move Bash Files";
    serviceConfig ={
      ExecStart = myscript;
      Type = "oneshot";
      User = "temhr";
    };
    startAt = "*:0/2";
  };
}
