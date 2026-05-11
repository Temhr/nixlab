{
  allHosts,
  flakePath,
  lib,
  pkgs,
  ...
}: {
  home.file = {
    # Root level bash files - using relative paths from flake root
    ".bash_profile".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash_profile";
    ".bashrc".source = lib.mkForce "${flakePath}/home/common/files/bash/.bashrc";

    # Custom append to existing bash file
    ".bash/bash_aliases".source = lib.mkForce (
      pkgs.writeText "bash_aliases" ''
        ${builtins.readFile "${flakePath}/home/common/files/bash/.bash/bash_aliases"}

        ##SSH Shortcuts - Dynamically generated from allHosts
        alias nixace='ssh temhr@${allHosts.nixace.address}'
        alias nixnas1='ssh temhr@${allHosts.nixnas1.address}'
        alias nixnas2='ssh temhr@${allHosts.nixnas2.address}'
        alias nixsun='ssh temhr@${allHosts.nixsun.address}'
        alias nixtop='ssh temhr@${allHosts.nixtop.address}'
        alias nixvat='ssh temhr@${allHosts.nixvat.address}'
        alias nixzen='ssh temhr@${allHosts.nixzen.address}'
      ''
    );

    # Files from the .bash/ subdirectory in your source
    ".bash/bash_functions".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/bash_functions";
    ".bash/bash_prompt".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/bash_prompt";
    ".bash/emoticons".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/emoticons";
    ".bash/environment_variables".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/environment_variables";
    ".bash/ghostty_themes.txt".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/ghostty_themes.txt";

    # Make the theme randomizer executable
    ".bash/ghostty_theme_randomizer" = {
      source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/ghostty_theme_randomizer";
      executable = true;
    };
  };
  # Configure bash through Home Manager for better integration
  programs.bash = {
    enable = true;

    # History settings
    historySize = 50000;
    historyFileSize = 100000;
    historyControl = ["ignoredups" "ignorespace" "erasedups"];

    # This will be appended to the Home Manager generated .bashrc
    # You can remove this if your .bashrc file already handles sourcing
    bashrcExtra = ''
      # Your custom bashrc is already symlinked, so this is just for any additional config
      # The symlinked .bashrc will take precedence
    '';
  };
}
