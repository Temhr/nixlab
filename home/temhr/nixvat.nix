{...}: {
  flake.temhr-nixvat.temhr-nixvat = {
    self,
    pkgs,
    ...
  }: {
    imports = [
      self.homeModules.home--c-global
      self.homeModules.home--c-optional
    ];

    # Add stuff for your user as you see fit:
    home = {
      enableNixpkgsReleaseCheck = false;
      username = "temhr";
      homeDirectory = "/home/temhr";
      #Environment Variables
      sessionVariables = {
      };
      packages = with pkgs; [
        # steam
      ];
    };

    # Let home Manager install and manage itself.
    programs.home-manager.enable = true;

    # Git Config
    programs.git.enable = true; #Distributed version control system
    programs.git.settings.user.name = "Temhr";
    programs.git.settings.user.email = "9110264+Temhr@users.noreply.github.com";

    # Extra Browsers
    brave.enable = true;
    chrome.enable = true;
    #edge.enable = true;
    zen.enable = true;

    ## Extra Terminal Emulators
    #alacritty.enable = true;  #Cross-platform, GPU-accelerated terminal emulator
    ghostty.enable = true; #fast, feature-rich, and cross-platform terminal emulator that uses platform-native UI and GPU acceleration
    #kitty.enable = true;  #Modern, hackable, featureful, OpenGL based terminal emulator
    #konsole.enable = true;  #Terminal emulator by KDE

    # Nicely reload system units when changing configs
    systemd.user.startServices = "sd-switch";

    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    home.stateVersion = "24.11";
  };
}
