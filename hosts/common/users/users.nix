{ pkgs, ... }: {

  # Configure your system-wide user settings (groups, etc), add more users as needed.
  users.users = {
    guest = {
      isNormalUser = true;
      initialPassword = "";
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKITqIX76nKk6GvwM//USjaBD+YruF7YiTJxMNXUXVu2 temhr" ]; # Add your SSH public key(s) here, if you plan on using SSH to connect
    };
  };
}
