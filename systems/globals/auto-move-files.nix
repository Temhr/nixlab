{ config, lib, pkgs, ... }:

let
    MoveBash = pkgs.writeShellScript "MoveBash.sh" ''
       cp /home/temhr/nixlab/bin/bash/.bash_profile /home/temhr/.bash_profile &&
       cp /home/temhr/nixlab/bin/bash/.bashrc /home/temhr/.bashrc &&
       cp /home/temhr/nixlab/bin/bash/.bash/bash_aliases /home/temhr/.bash/bash_aliases &&
       cp /home/temhr/nixlab/bin/bash/.bash/bash_functions /home/temhr/.bash/bash_functions &&
       cp /home/temhr/nixlab/bin/bash/.bash/bash_prompt /home/temhr/.bash/bash_prompt &&
       cp /home/temhr/nixlab/bin/bash/.bash/emoticons /home/temhr/.bash/emoticons &&
       cp /home/temhr/nixlab/bin/bash/.bash/environment_variables /home/temhr/.bash/environment_variables &&
       cp /home/temhr/nixlab/bin/bash/.bash/ghostty_fonts.txt /home/temhr/.bash/ghostty_fonts.txt &&
       cp /home/temhr/nixlab/bin/bash/.bash/ghostty_theme_randomizer /home/temhr/.bash/ghostty_theme_randomizer &&
       cp /home/temhr/nixlab/bin/bash/.bash/ghostty_themes.txt /home/temhr/.bash/ghostty_themes.txt

    '';
in

{
  systemd.services.MoveBash = {
    description = "Move Bash Files";
    serviceConfig ={
      ExecStart = MoveBash;
      Type = "oneshot";
      User = "temhr";
    };
    startAt = "03:00";
  };
}
