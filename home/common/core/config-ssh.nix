# Configure SSH for interactive git operations using sops-managed keys
{...}: {
  flake.homeModules.home--core--config-ssh = {allHosts, ...}: let
    knownHostsContent = ''
      ${allHosts.nixace.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINb+dep4WR66B6pN1RnD4zOaaXbQ7BeP4kMYEogxm4uw
      ${allHosts.nixsun.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAbIHaFx/TMMHN0u3nCPkWsRRZftuo13SqBQl7t8aJQB
      ${allHosts.nixvat.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINcqvMDczeLZ30PYuO84CVmSgZtALxDsRe4FW/NhMu3U
      ${allHosts.nixtop.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGw2308+cJc73xCDEP0Nwcmq4ukXF3n+URNi+5/F/oH
      ${allHosts.nixzen.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAh/ymwvcsU3BllR+nJzc75e2lFvxXFjep99Pk7cMSoo
      ${allHosts.nixnas1.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPNNcboFPyQsfJKekGrHQp566uJLSwvHHbdtHFYfM7+t
      ${allHosts.nixnas2.address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHaw2+5d8qk4IYCgNCDTG8uJyyArYlU3KivUQECTGnuw
      github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    '';
  in {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."github.com" = {
        identityFile = "~/.ssh/id_github";
        identitiesOnly = true;
        extraOptions.AddKeysToAgent = "yes";
      };
    };

    home.file = {
      ".ssh/.keep".text = "";
      ".ssh/.keep".onChange = ''chmod 700 ~/.ssh'';

      ".ssh/known_hosts" = {
        force = true;
        text = knownHostsContent;
      };
      ".ssh/known_hosts.old" = {
        force = true;
        text = knownHostsContent;
      };
    };
  };
}
