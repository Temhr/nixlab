{ config, lib, pkgs, ... }: {

  # Create a system user with minimal permissions
  users.users.temhrbot = {
    # System user (no login shell)
    isSystemUser = true;
    group = "temhrbot";
    #extraGroups = [ "users"];
    # Explicitly set shell to prevent any interactive login
    shell = "/run/current-system/sw/bin/nologin";

    # Minimal home directory for potential script storage
    home = "/var/lib/temhrbot";
    createHome = true;

    # Packages needed for git operations
    packages = with pkgs; [
      git  # Git version control
      openssh  # For SSH operations with GitHub
    ];
  };

  # Create a corresponding group
  users.groups.temhrbot = {};

  # Optional: Configure sudo access for specific git operations
  # This allows the user to run specific git commands via sudo
  security.sudo = {
    enable = true;
    extraRules = [
      {
        users = [ "temhrbot" ];
        commands = [
          {
            command = "${pkgs.nix}/bin/nix";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.git}/bin/git";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
