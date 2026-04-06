{pkgs, ...}: {
  home.packages = with pkgs; [
    git
    unstable.git-cola #Sleek and powerful Git GUI
    unstable.ungit #Git made easy
    git-credential-keepassxc #Helper that allows Git (and shell scripts) to use KeePassXC as credential store
  ];
  programs.git.enable = true; #Distributed version control system
  programs.lazygit.enable = true; #A simple terminal UI for git commands
}
