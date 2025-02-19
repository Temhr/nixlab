{ config, ... }: {

  programs.firefox = {
    enable = true;
    languagePacks = [ "en-CA" ];

    /* ---- POLICIES ---- */
    # Check about:policies#documentation for options.
    policies = {
      DisableAccounts = true;  #Disable account-based services, including sync
      DisableFirefoxAccounts = true;  #Disable account-based services, including sync
      DisableFirefoxScreenshots = true;  #Disable the Firefox Screenshots feature
      DisableFirefoxStudies = true;  #Prevent Firefox from running studies
      DisablePocket = true;  #saves webpages to Pocket
      DisableTelemetry = true; #Turn off Telemetry.
      DisplayBookmarksToolbar = "always"; # alternatives: "always" or "newtab"
      DisplayMenuBar = "default-on"; # alternatives: "always", "never" or "default-off"
      DontCheckDefaultBrowser = true;
      #Enable or disable Content Blocking and optionally lock it
      EnableTrackingProtection = {
        Value= true;  #true, tracking protection is enabled by default in regular and private browsing
          Locked = true;
        Cryptomining = true;  #true, cryptomining scripts on websites are blocked
        Fingerprinting = true;  #true, fingerprinting scripts on websites are blocked
      };
      OverrideFirstRunPage = "";  #blank if you want to disable the first run page
      OverridePostUpdatePage = "";  #blank if you want to disable the post-update page
      SearchBar = "unified"; # alternative: "separate"

      /* ---- EXTENSIONS ---- */
      # Check about:support for extension/add-on ID strings.
      # Valid strings for installation_mode are "allowed", "blocked",
      # "force_installed" and "normal_installed".
      ExtensionSettings = {
        "*".installation_mode = "blocked"; # blocks all addons except the ones specified below
        # Augmented Steam:
        "augmentedsteam@isthereanydeal.com" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/augmented-steam/latest.xpi";
          installation_mode = "force_installed";
        };
        # BetterTTV:
        "firefox@betterttv.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/betterttv/latest.xpi";
          installation_mode = "force_installed";
        };
        # Enhancer for YouTube:
        "enhancerforyoutube@maximerf.addons.mozilla.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/enhancer-for-youtube/latest.xpi";
          installation_mode = "force_installed";
        };
        # floccus bookmarks sync:
        "floccus@handmadeideas.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/floccus/latest.xpi";
          installation_mode = "force_installed";
        };
        # KeePassXC-Browser:
        "keepassxc-browser@keepassxc.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/keepassxc-browser/latest.xpi";
          installation_mode = "force_installed";
        };
        # Privacy Badger:
        "jid1-MnnxcxisBPnSXQ@jetpack" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
          installation_mode = "force_installed";
        };
        # Reddit Enhancement Suite:
        "jid1-xUfzOsOFlzSOXg@jetpack" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/reddit-enhancement-suite/latest.xpi";
          installation_mode = "force_installed";
        };
        # To Google Translate:
        "juanmauricioescobar@gmail.com" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/file/3798719/to_google_translate-4.2.0.xpi";
          installation_mode = "force_installed";
        };
        # Sort Bookmarks:
        "sort-bookmarks@heftig" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/sort-bookmarks-webext/latest.xpi";
          installation_mode = "force_installed";
        };
        # uBlock Origin:
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        # Video Speed Controller:
        "{7be2ba16-0f1e-4d93-9ebc-5164397477a9}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/videospeed/latest.xpi";
          installation_mode = "force_installed";
        };
        # Youtube Playlist Duration Calculator:
        "{36d78ab3-8f38-444a-baee-cb4a0cadbf98}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/youtube-playlist-duration-calc/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };
  };

}
