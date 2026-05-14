# home/common/global/ssh-config.nix
# Configure SSH for interactive git operations using sops-managed keys
{self, ...}: {
  flake.homeModules.common-global--ssh-config = {
    config,
    lib,
    pkgs,
    ...
  }: {
    programs.ssh = {
      enable = true;

      # Configure SSH to use the sops-managed key for GitHub
      matchBlocks = {
        "github.com" = {
          identityFile = "~/.ssh/id_github_nixlab";
          identitiesOnly = true;
          extraOptions = {
            AddKeysToAgent = "yes";
          };
        };
      };
    };

    # Ensure .ssh directory exists with correct permissions
    home.file.".ssh/.keep".text = "";
    home.file.".ssh/.keep".onChange = ''
      chmod 700 ~/.ssh
    '';
  };
}
