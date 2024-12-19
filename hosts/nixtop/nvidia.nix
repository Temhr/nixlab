{lib, ...}: {
  i18n = {
    ## Select internationalisation properties.
    defaultLocale = lib.mkDefault "en_CA.UTF-8";
  };
  location.provider = "geoclue2";
  ## Set your time zone.
  time.timeZone = lib.mkDefault "America/Toronto";
}
