# home.nix - Home Manager configuration matching your actual file structure
{ config, lib, pkgs, self, ... }:

{
  home.file = {
    # Root level bash files - using relative paths from flake root
    ".bash_profile".source = lib.mkForce "${self}/home/files/bash/.bash_profile";
    ".bashrc".source = lib.mkForce "${self}/home/files/bash/.bashrc";

    # Files from the .bash/ subdirectory in your source
    ".bash/bash_aliases".source = lib.mkForce "${self}/home/files/bash/.bash/bash_aliases";
    ".bash/bash_functions".source = lib.mkForce "${self}/home/files/bash/.bash/bash_functions";
    ".bash/bash_prompt".source = lib.mkForce "${self}/home/files/bash/.bash/bash_prompt";
    ".bash/emoticons".source = lib.mkForce "${self}/home/files/bash/.bash/emoticons";
    ".bash/environment_variables".source = lib.mkForce "${self}/home/files/bash/.bash/environment_variables";
    ".bash/ghostty_themes.txt".source = lib.mkForce "${self}/home/files/bash/.bash/ghostty_themes.txt";

    # Make the theme randomizer executable
    ".bash/ghostty_theme_randomizer" = {
      source = lib.mkForce "${self}/home/files/bash/.bash/ghostty_theme_randomizer";
      executable = true;
    };

    # symlink
    #"Pictures/Wallpapers/mirk1/".source = lib.mkForce "${self}/../../../mnt/mirk1/Hard Drive Backup/Users/Efrem 2017/Pictures/Wallpapers/";
    #"Pictures/Wallpapers/mirk3/".source = lib.mkForce "${self}/../../../mnt/mirk3/Hard Drive Backup/Users/Efrem 2017/Pictures/Wallpapers/";
    #"Pictures/Wallpapers/mirror/".source = lib.mkForce "${self}/../../../mirror/Hard Drive Backup/Users/Efrem 2017/Pictures/Wallpapers/";
  };

  # Configure bash through Home Manager for better integration
  programs.bash = {
    enable = true;

    # History settings
    historySize = 50000;
    historyFileSize = 100000;
    historyControl = [ "ignoredups" "ignorespace" "erasedups" ];

    # This will be appended to the Home Manager generated .bashrc
    # You can remove this if your .bashrc file already handles sourcing
    bashrcExtra = ''
      # Your custom bashrc is already symlinked, so this is just for any additional config
      # The symlinked .bashrc will take precedence
    '';
  };
}
