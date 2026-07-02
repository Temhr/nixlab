{...}: {
  flake.nixosModules.hosts--deskt--cache-tmpfs = {config, ...}: {
    # Reduce writes to storage - keep /home with low-write mount options
    fileSystems."/home".options = ["relatime" "noatime"];

    # Move browser cache to tmpfs to reduce disk writes
    systemd.tmpfiles.rules = [
      "L+ /home/${config.nixlab.mainUser}/.cache - - - - /tmp/user-cache"
      "d /tmp/user-cache 0700 ${config.nixlab.mainUser} users -"
    ];
  };
}
