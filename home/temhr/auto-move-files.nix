{ pkgs, ... }:
let
  MoveFilesShellScript = pkgs.writeShellScript "auto-move-files.sh" ''
    cp /home/temhr/nixlab/home/files/bash/.bash_profile /home/temhr/.bash_profile &&
    cp /home/temhr/nixlab/home/files/bash/.bashrc /home/temhr/.bashrc &&
    cp /home/temhr/nixlab/home/files/bash/bash_aliases /home/temhr/.bash/bash_aliases &&
    cp /home/temhr/nixlab/home/files/bash/bash_functions /home/temhr/.bash/bash_functions &&
    cp /home/temhr/nixlab/home/files/bash/bash_prompt /home/temhr/.bash/bash_prompt &&
    cp /home/temhr/nixlab/home/files/bash/emoticons /home/temhr/.bash/emoticons &&
    cp /home/temhr/nixlab/home/files/bash/environment_variables /home/temhr/.bash/environment_variables &&
    cp /home/temhr/nixlab/home/files/bash/ghostty_theme_randomizer /home/temhr/.bash/ghostty_theme_randomizer &&
    cp /home/temhr/nixlab/home/files/bash/ghostty_themes.txt /home/temhr/.bash/ghostty_themes.txt
  '';
in
{
  systemd."temhr".timers.move-files = {
    Unit = {
      Description = "Nightly copy/move bash and config files (timer)";
    };
    Timer = {
      OnCalendar = "daily"; # Runs once per day at midnight by default
      Persistent = true;
      Unit = "move-files.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  systemd."temhr".services.move-files = {
    Unit = {
      Description = "Nightly copy/move bash and config files (user service)";
    };
    Service = {
      ExecStart = "${MoveFilesShellScript}";
      Type = "oneshot";
    };
  };
}
