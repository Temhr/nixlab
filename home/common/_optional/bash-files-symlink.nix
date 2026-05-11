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

    # ssh injection of hostname/IPs
    ".ssh/known_hosts".force = true;
    ".ssh/known_hosts".text = "
      ${allHosts.nixace.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINb+dep4WR66B6pN1RnD4zOaaXbQ7BeP4kMYEogxm4uw
      ${allHosts.nixsun.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAbIHaFx/TMMHN0u3nCPkWsRRZftuo13SqBQl7t8aJQB
      ${allHosts.nixvat.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINcqvMDczeLZ30PYuO84CVmSgZtALxDsRe4FW/NhMu3U
      ${allHosts.nixtop.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGw2308+cJc73xCDEP0Nwcmq4ukXF3n+URNi+5/F/oH
      ${allHosts.nixzen.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAh/ymwvcsU3BllR+nJzc75e2lFvxXFjep99Pk7cMSoo
      ${allHosts.nixnas1.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPNNcboFPyQsfJKekGrHQp566uJLSwvHHbdtHFYfM7+t
      ${allHosts.nixnas2.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHaw2+5d8qk4IYCgNCDTG8uJyyArYlU3KivUQECTGnuw
      github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    ";
    ".ssh/known_hosts.old".force = true;
    ".ssh/known_hosts.old".text = "
      ${allHosts.nixace.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINb+dep4WR66B6pN1RnD4zOaaXbQ7BeP4kMYEogxm4uw
      ${allHosts.nixsun.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAbIHaFx/TMMHN0u3nCPkWsRRZftuo13SqBQl7t8aJQB
      ${allHosts.nixvat.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINcqvMDczeLZ30PYuO84CVmSgZtALxDsRe4FW/NhMu3U
      ${allHosts.nixtop.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGw2308+cJc73xCDEP0Nwcmq4ukXF3n+URNi+5/F/oH
      ${allHosts.nixzen.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAh/ymwvcsU3BllR+nJzc75e2lFvxXFjep99Pk7cMSoo
      ${allHosts.nixnas1.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPNNcboFPyQsfJKekGrHQp566uJLSwvHHbdtHFYfM7+t
      ${allHosts.nixnas2.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHaw2+5d8qk4IYCgNCDTG8uJyyArYlU3KivUQECTGnuw
      github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    ";
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
