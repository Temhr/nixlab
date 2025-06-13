# home.nix - Home Manager configuration for bash files
{ config, pkgs, ... }:

{
  # Direct file management - files are symlinked automatically
  home.file = {
    # Main bash configuration files
    ".bash_profile".source = ./nixlab/home/files/bash/.bash_profile;
    ".bashrc".source = ./nixlab/home/files/bash/.bashrc;

    # Bash utility files in ~/.bash/ directory
    ".bash/bash_aliases".source = ./nixlab/home/files/bash/bash_aliases;
    ".bash/bash_functions".source = ./nixlab/home/files/bash/bash_functions;
    ".bash/bash_prompt".source = ./nixlab/home/files/bash/bash_prompt;
    ".bash/emoticons".source = ./nixlab/home/files/bash/emoticons;
    ".bash/environment_variables".source = ./nixlab/home/files/bash/environment_variables;
    ".bash/ghostty_themes.txt".source = ./nixlab/home/files/bash/ghostty_themes.txt;

    # Make ghostty theme randomizer executable
    ".bash/ghostty_theme_randomizer" = {
      source = ./nixlab/home/files/bash/ghostty_theme_randomizer;
      executable = true;
    };
  };

  # Alternative approach: Using programs.bash for better integration
  programs.bash = {
    enable = true;

    # You can also manage bash configuration directly here instead of separate files
    # bashrcExtra = ''
    #   # Additional bash configuration can go here
    #   # This gets appended to the generated .bashrc
    # '';

    # profileExtra = ''
    #   # Additional profile configuration
    #   # This gets appended to the generated .bash_profile
    # '';

    # Shell aliases (alternative to separate bash_aliases file)
    # shellAliases = {
    #   ll = "ls -alF";
    #   la = "ls -A";
    #   l = "ls -CF";
    # };

    # History configuration
    historySize = 10000;
    historyFileSize = 20000;
    historyControl = [ "ignoredups" "ignorespace" ];
  };

  # If you want to keep using your existing separate files but with some Home Manager benefits:
  # You can create a systemd user service that runs on home-manager switch
  systemd.user.services.bash-config-refresh = {
    Unit = {
      Description = "Refresh bash configuration after home-manager switch";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'source ~/.bash_profile 2>/dev/null || true'";
      RemainAfterExit = true;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
