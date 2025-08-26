{ ... }: {

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";  # Optional: disables lid action even when docked
    HandleLidSwitchExternalPower = "ignore"; # Optional: disables lid action when charging
  };
}
