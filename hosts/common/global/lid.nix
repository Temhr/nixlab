{ ... }: {

  services.logind = {
    lidSwitch = "ignore";
    lidSwitchDocked = "ignore";  # Optional: disables lid action even when docked
    lidSwitchExternalPower = "ignore"; # Optional: disables lid action when charging
  };
}
