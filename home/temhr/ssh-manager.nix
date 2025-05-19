{ config, pkgs, ... }: {

  ## === SHELL === ##
  programs.bash.enable = true;

  ## === GIT === ##
  programs.git = {
    enable = true;
    userName = "Temhr";
    userEmail = "9110264+Temhr@users.noreply.github.com";
  };

  ## === SSH === ##
  programs.ssh = {
    enable = true;
    startAgent = true;  # start ssh-agent
    matchBlocks = {
      "nixlab" = {
        hostname = "github.com";
        user = "temhr";
        identityFile = "~/.ssh/id_ed25519_nixlab";
        identitiesOnly = true;
      };
    };
  };

  programs.ssh.startAgent = true;
  services.ssh-agent.enable = true;

  # Link SSH keys from a persistent location (for impermanence)
  #home.file.".ssh/id_ed25519_nixlab".source = "/persist/home/temhr/.ssh/id_ed25519_nixlab";
  #home.file.".ssh/id_ed25519_nixlab.pub".source = "/persist/home/temhr/.ssh/id_ed25519_nixlab.pub";

}
