{ lib, ... }: {
  ## Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = lib.mkDefault "guest";
}
