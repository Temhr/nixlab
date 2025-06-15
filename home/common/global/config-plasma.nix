# ./home-manager/temhr.nix (or your Home Manager user configuration file)
{ config, lib, pkgs, ... }:

{
  programs.plasma = {
    enable = true;

    # Workspace appearance and behavior
    workspace = {
      # Look and feel theme
      lookAndFeel = "org.kde.breezedark.desktop";
      # Available options: "org.kde.breeze.desktop", "org.kde.breezedark.desktop"

      # Color scheme
      colorScheme = "BreezeDark";
      # Available: "Breeze", "BreezeDark", or custom scheme names

      # Cursor theme
      cursor = {
        theme = "breeze_cursors";
        size = 24;
      };

      # Icon theme
      iconTheme = "breeze-dark";

      # Plasma theme
      theme = "breeze-dark";

      # Wallpaper
      wallpaperSlideShow = {
        # Enable wallpaper slideshow
        enable = true;

        # Path to directory containing wallpapers
        path = "/home/temhr/Pictures/Wallpapers";

        # Alternative: specify multiple paths
        # paths = [
        #   "/home/username/Pictures/Wallpapers"
        #   "/home/username/Pictures/Nature"
        #   "/usr/share/pixmaps"
        # ];

        # Change interval in seconds
        interval = 300;  # 5 minutes

        # Slideshow mode options:
        # - "Random" - random order
        # - "Alphabetical" - alphabetical order
        # - "AlphabeticalReversed" - reverse alphabetical
        # - "Modified" - by modification time
        # - "ModifiedReversed" - reverse modification time
        mode = "Random";

        # Image scaling/positioning options:
        # - "Stretch" - stretch to fill screen
        # - "Fit" - fit to screen maintaining aspect ratio
        # - "Fill" - fill screen, may crop image
        # - "Center" - center image at original size
        # - "Tile" - tile image
        # - "CenterTiled" - center and tile
        fillMode = "Fill";

        # Background color (used with some fill modes)
        # Format: "#RRGGBB" or color name
        color = "#000000";

        # Blur background when image doesn't fill screen
        blur = false;

        # Uncrop: expand image to fill screen boundaries
        uncrop = 0.0;  # 0.0 = no uncrop, 1.0 = maximum uncrop

        # Image filters
        filters = {
          # Brightness adjustment (-1.0 to 1.0)
          brightness = 0.0;

          # Contrast adjustment (-1.0 to 1.0)
          contrast = 0.0;

          # Saturation adjustment (-1.0 to 1.0)
          saturation = 0.0;
        };

        # Pause slideshow when on battery (laptop)
        pauseOnBattery = false;

        # Pause slideshow when running on low battery
        pauseOnLowBattery = true;

        # Battery threshold percentage for low battery pause
        lowBatteryThreshold = 20;
      };

      # Window decorations
      windowDecorations = {
        library = "org.kde.breeze";
        theme = "Breeze";
      };
    };

/*
    # Fonts configuration
    fonts = {
      general = {
        family = "Noto Sans";
        pointSize = 10;
      };
      fixedWidth = {
        family = "Hack";
        pointSize = 10;
      };
      small = {
        family = "Noto Sans";
        pointSize = 8;
      };
      toolbar = {
        family = "Noto Sans";
        pointSize = 10;
      };
      menu = {
        family = "Noto Sans";
        pointSize = 10;
      };
      windowTitle = {
        family = "Noto Sans";
        pointSize = 10;
      };
    };

    # Panel configuration
    panels = [
      # Bottom panel (taskbar)
      {
        location = "bottom";
        height = 44;
        hiding = "none"; # "none", "autohide", "windowscover", "windowsbelow"
        alignment = "center";
        lengthMode = "fill"; # "fit", "fill", "custom"
        floating = false;
        opacity = "adaptive"; # "adaptive", "opaque", "translucent"

        widgets = [
          # Application launcher
          {
            name = "org.kde.plasma.kickoff";
            config = {
              General = {
                icon = "start-here-kde";
                alphaSort = true;
              };
            };
          }

          # Pager (virtual desktops)
          "org.kde.plasma.pager"

          # Task manager
          {
            name = "org.kde.plasma.icontasks";
            config = {
              General = {
                launchers = [
                  "applications:org.kde.konsole.desktop"
                  "applications:org.kde.dolphin.desktop"
                  "applications:firefox.desktop"
                ];
                showOnlyCurrentDesktop = false;
                groupingStrategy = 0; # 0 = do not group, 1 = by program name
                sortingStrategy = 1; # 0 = do not sort, 1 = by desktop, 2 = by activity
              };
            };
          }

          # Spacer
          "org.kde.plasma.marginsseparator"

          # System tray
          {
            name = "org.kde.plasma.systemtray";
            config = {
              General = {
                extraItems = [
                  "org.kde.plasma.clipboard"
                  "org.kde.plasma.devicenotifier"
                  "org.kde.plasma.manage-inputmethod"
                  "org.kde.plasma.mediacontroller"
                  "org.kde.plasma.notifications"
                  "org.kde.plasma.keyboardlayout"
                  "org.kde.plasma.networkmanagement"
                  "org.kde.plasma.volume"
                  "org.kde.plasma.bluetooth"
                  "org.kde.plasma.battery"
                ];
                hiddenItems = [
                  "org.kde.plasma.clipboard"
                ];
              };
            };
          }

          # Digital clock
          {
            name = "org.kde.plasma.digitalclock";
            config = {
              Appearance = {
                showDate = true;
                showSeconds = false;
                use24hFormat = 2; # 0 = 12h, 1 = 24h, 2 = system default
                dateFormat = "isoDate"; # "longDate", "shortDate", "isoDate"
              };
            };
          }

          # Show desktop button
          "org.kde.plasma.showdesktop"
        ];
      }

      # Top panel (optional)
      {
        location = "top";
        height = 26;
        hiding = "none";
        widgets = [
          # Global menu
          "org.kde.plasma.appmenu"

          "org.kde.plasma.marginsseparator"

          # Window title
          "org.kde.plasma.windowtitle"

          "org.kde.plasma.marginsseparator"

          # System monitor widgets
          {
            name = "org.kde.plasma.systemmonitor";
            config = {
              General = {
                showTitle = false;
                displayStyle = "org.kde.ksysguard.textonly";
              };
              Sensors = {
                highPrioritySensorIds = ["cpu/all/usage"];
              };
            };
          }
        ];
      }
    ];

    # Desktop and window behavior
    desktop = {
      # Mouse settings
      mouseActions = {
        leftClick = "switchWindow";
        middleClick = "paste";
        rightClick = "contextMenu";
        verticalScroll = "switchWindow";
      };

      # Desktop icons
      icons = {
        size = 2; # 0=small, 1=medium, 2=large, 3=huge
        alignment = 0; # 0=left, 1=right
        locked = false;
        sorting = 0; # 0=name, 1=size, 2=type, 3=date
      };
    };

    # Window management
    window-rules = [
      {
        description = "Konsole transparency";
        match = {
          window-class = {
            value = "konsole";
            type = "substring";
          };
        };
        apply = {
          opacityactive = {
            value = 90;
            apply = "force";
          };
          opacityinactive = {
            value = 80;
            apply = "force";
          };
        };
      }
      {
        description = "Firefox PiP always on top";
        match = {
          window-class = {
            value = "firefox";
            type = "substring";
          };
          window-types = [ "utility" ];
        };
        apply = {
          above = {
            value = true;
            apply = "force";
          };
        };
      }
    ];

    # Keyboard shortcuts
    shortcuts = {
      # System shortcuts
      ksmserver = {
        "Lock Session" = [ "Screensaver" "Meta+Ctrl+Alt+L" ];
        "Log Out" = "Ctrl+Alt+Del";
      };

      # Window management
      kwin = {
        # Window switching
        "Switch Window Down" = "Meta+J";
        "Switch Window Up" = "Meta+K";
        "Switch Window Left" = "Meta+H";
        "Switch Window Right" = "Meta+L";

        # Virtual desktops
        "Switch to Desktop 1" = "Meta+1";
        "Switch to Desktop 2" = "Meta+2";
        "Switch to Desktop 3" = "Meta+3";
        "Switch to Desktop 4" = "Meta+4";

        # Window tiling
        "Window Quick Tile Left" = "Meta+Left";
        "Window Quick Tile Right" = "Meta+Right";
        "Window Maximize" = "Meta+Up";
        "Window Minimize" = "Meta+Down";

        # Expose and overview
        "Expose" = "Meta+,";
        "ExposeAll" = "Meta+.";
        "ShowDesktopGrid" = "Meta+F8";

        # Other window actions
        "Window Close" = "Alt+F4";
        "Window Operations Menu" = "Alt+F3";
        "Toggle Window Fullscreen" = "Meta+F";
      };

      # Application shortcuts
      kded5 = {
        "Show System Activity" = "Meta+Escape";
        "display" = [ "Display" "Meta+P" ];
      };

      # Custom application shortcuts
      "services/org.kde.konsole.desktop" = {
        "_launch" = [ "Meta+Return" "Ctrl+Alt+T" ];
      };
      "services/org.kde.dolphin.desktop" = {
        "_launch" = "Meta+E";
      };
      "services/firefox.desktop" = {
        "_launch" = "Meta+B";
      };
    };

    # KDE Connect
    kdeconnect = {
      enable = true;
      name = "nixos-desktop";
    };

    # Power management
    powerdevil = {
      AC = {
        autoSuspend = {
          action = "nothing";
          idleTimeout = 0;
        };
        turnOffDisplay = {
          idleTimeout = 300; # 5 minutes
        };
        whenSleepingEnter = "standbyThenSuspend";
        whenLaptopLidClosed = "turnOffScreen";
        inhibitLidActionWhenExternalMonitorConnected = true;
      };

      battery = {
        autoSuspend = {
          action = "suspend";
          idleTimeout = 600; # 10 minutes
        };
        turnOffDisplay = {
          idleTimeout = 120; # 2 minutes
        };
        whenSleepingEnter = "standbyThenSuspend";
        whenLaptopLidClosed = "suspend";
        inhibitLidActionWhenExternalMonitorConnected = true;
      };

      lowBattery = {
        autoSuspend = {
          action = "hibernate";
          idleTimeout = 300; # 5 minutes
        };
        turnOffDisplay = {
          idleTimeout = 60; # 1 minute
        };
        whenSleepingEnter = "standbyThenSuspend";
        whenLaptopLidClosed = "hibernate";
        inhibitLidActionWhenExternalMonitorConnected = false;
      };
    };
*/

    # Hot corners
    hotCorners = {
      topLeft = "showDesktop";
      topRight = "showApplicationLauncher";
      bottomLeft = "activityManager";
      bottomRight = "none";
    };
/*
    # Virtual desktops
    virtualDesktops = {
      rows = 2;
      columns = 2;
      names = [
        "Main"
        "Web"
        "Development"
        "Media"
      ];
    };

    # Spectacle (screenshot tool)
    spectacle = {
      shortcuts = {
        captureActiveWindow = "Meta+Print";
        captureCurrentMonitor = "Print";
        captureEntireDesktop = "Shift+Print";
        captureRectangularRegion = "Meta+Shift+Print";
        recordRegion = "Meta+Alt+R";
        recordScreen = "Meta+Shift+R";
        recordWindow = "Meta+Ctrl+R";
      };
    };
*/

    # Dolphin file manager
    dolphin = {
      general = {
        browseArchives = true;
        openExternallyCalledFolderInNewTab = true;
        showFullPath = true;
        showSpaceInfo = true;
        showToolTips = true;
        useTabForSwitchingSplitView = true;
      };

      search = {
        location = "everywhere";
      };
    };

/*
    # Konsole terminal
    konsole = {
      defaultProfile = "custom";
      profiles = {
        custom = {
          colorScheme = "Breeze";
          font = {
            family = "Hack";
            size = 11;
          };
          scrollBarPosition = "right";
          showMenuBarByDefault = false;
        };
      };
    };

    # KRunner (Alt+Space launcher)
    krunner = {
      position = "center";
      historyBehavior = "enableSuggestions";
      retainPriorSearch = true;
    };

    # Notification settings
    notifications = {
      criticalInFullscreen = true;
      popupTimeout = 5000; # 5 seconds
    };

    # Input method settings
    input = {
      keyboard = {
        layouts = [
          {
            layout = "us";
            variant = "";
          }
          {
            layout = "de";
            variant = "";
          }
        ];
        options = [ "grp:alt_shift_toggle" ];
      };

      mouse = {
        acceleration = 0.0;
        threshold = 0;
        leftHanded = false;
        middleButtonEmulation = false;
        naturalScroll = false;
      };

      touchpad = {
        naturalScroll = true;
        tapToClick = true;
        scrollTwoFinger = true;
        middleClickPaste = true;
        disableWhileTyping = true;
      };
    };
  };

  # Additional KDE/Qt applications configuration
  programs.kate = {
    enable = true;
  };

  programs.okular = {
    enable = true;
  };

  # Ensure necessary packages are available
  home.packages = with pkgs; [
    # Additional KDE applications
    kdePackages.konsole
    kdePackages.dolphin
    kdePackages.kate
    kdePackages.okular
    kdePackages.spectacle
    kdePackages.kdeconnect-kde

    # Fonts that work well with KDE
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    hack-font
    source-code-pro
  ];

*/
}
