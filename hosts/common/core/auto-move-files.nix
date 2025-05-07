{ pkgs, ... }:
let
    MoveFilesShellScript = pkgs.writeShellScript "auto-move-files.sh" ''
       cp /home/temhr/nixlab/home/temhr/files/bash/.bash_profile /home/temhr/.bash_profile &&
       cp /home/temhr/nixlab/home/temhr/files/bash/.bashrc /home/temhr/.bashrc &&
       cp /home/temhr/nixlab/home/temhr/files/bash/bash_aliases /home/temhr/.bash/bash_aliases &&
       cp /home/temhr/nixlab/home/temhr/files/bash/bash_functions /home/temhr/.bash/bash_functions &&
       cp /home/temhr/nixlab/home/temhr/files/bash/bash_prompt /home/temhr/.bash/bash_prompt &&
       cp /home/temhr/nixlab/home/temhr/files/bash/emoticons /home/temhr/.bash/emoticons &&
       cp /home/temhr/nixlab/home/temhr/files/bash/environment_variables /home/temhr/.bash/environment_variables &&
       cp /home/temhr/nixlab/home/temhr/files/bash/ghostty_theme_randomizer /home/temhr/.bash/ghostty_theme_randomizer &&
       cp /home/temhr/nixlab/home/temhr/files/bash/ghostty_themes.txt /home/temhr/.bash/ghostty_themes.txt
    '';
in
{
  systemd.services.move-files = {
    description = "Nightly copy/move bash and config Files";
    serviceConfig ={
      ExecStart = MoveFilesShellScript;
      Type = "oneshot";
      User = "temhr";
    };
    startAt = "03:00";
  };
}
