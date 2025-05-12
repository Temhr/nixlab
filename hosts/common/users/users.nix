{ pkgs, ... }: {

  # Configure your system-wide user settings (groups, etc), add more users as needed.
  users.users = {
    temhr = {
      #initialPassword = "correcthorsebatterystaple";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKITqIX76nKk6GvwM//USjaBD+YruF7YiTJxMNXUXVu2 temhr" ]; # Add your SSH public key(s) here, if you plan on using SSH to connect
      # Be sure to add any other groups you need (such as networkmanager, audio, docker, etc)
      #"adbusers" "kvm" => adb and android deveopment
      #"video" "render" => Blender user development
      extraGroups = [ "root" "wheel" "networkmanager" "adbusers" "kvm" "video" "render"];
      packages = with pkgs; [
      #  thunderbird
      ];
    };
    guest = {
      isNormalUser = true;
      initialPassword = "";
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKITqIX76nKk6GvwM//USjaBD+YruF7YiTJxMNXUXVu2 temhr" ]; # Add your SSH public key(s) here, if you plan on using SSH to connect
    };
  };
}
