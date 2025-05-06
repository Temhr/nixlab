{ ... }: {

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ## Limit the number of generations to present
  boot.loader.systemd-boot.configurationLimit = 10;

}
