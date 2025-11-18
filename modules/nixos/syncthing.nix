{ config, lib, pkgs, ... }:

let
  cfg = config.services.syncthing-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.syncthing-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Syncthing service";

      # REQUIRED: User to run Syncthing as
      # This user will own all synced files
      user = lib.mkOption {
        type = lib.types.str;
        default = "syncthing";
        example = "myuser";
        description = "User account under which Syncthing runs";
      };

      # OPTIONAL: Group for the Syncthing user (default: same as user)
      group = lib.mkOption {
        type = lib.types.str;
        default = cfg.user;
        example = "users";
        description = "Group for Syncthing user";
      };

      # OPTIONAL: Web GUI port (default: 8384)
      port = lib.mkOption {
        type = lib.types.port;
        default = 8384;
        description = "Port for Syncthing web GUI";
      };

      # OPTIONAL: IP to bind GUI to (default: 127.0.0.1 = localhost only)
      # Use "0.0.0.0" for access from other devices
      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address for web GUI (use 0.0.0.0 for all interfaces)";
      };

      # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "sync.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      # Only works if domain is set
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      # OPTIONAL: Where to store Syncthing config (default: varies by user)
      # For system user: /var/lib/syncthing
      # For regular user: /home/user/.config/syncthing
      dataDir = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/data/syncthing";
        description = "Directory for Syncthing configuration (null = auto)";
      };

      # OPTIONAL: Syncthing config directory (default: null = use dataDir/.config/syncthing)
      # This is the directory where config.xml and other settings are stored
      configDir = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/home/user/.config/syncthing";
        description = "Config directory for Syncthing settings (overrides auto-detection)";
      };

      # OPTIONAL: Override devices configured in web GUI (default: true)
      # When true, devices in config override GUI settings
      # When false, GUI settings take precedence
      overrideDevices = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Override devices configured in web GUI with Nix config";
      };

      # OPTIONAL: Override folders configured in web GUI (default: true)
      # When true, folders in config override GUI settings
      # When false, GUI settings take precedence
      overrideFolders = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Override folders configured in web GUI with Nix config";
      };

      # OPTIONAL: Devices to sync with (default: {})
      # Device IDs can be found in the Syncthing GUI: Actions → Show ID
      devices = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            id = lib.mkOption {
              type = lib.types.str;
              description = "Device ID (long string from 'Show ID' in GUI)";
            };
            addresses = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "dynamic" ];
              description = "List of addresses (use 'dynamic' for auto-discovery)";
            };
            introducer = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Allow this device to introduce other devices";
            };
          };
        });
        default = {};
        example = lib.literalExpression ''
          {
            "my-laptop" = {
              id = "DEVICE-ID-GOES-HERE";
              addresses = [ "dynamic" ];
            };
            "my-phone" = {
              id = "ANOTHER-DEVICE-ID";
              addresses = [ "dynamic" ];
            };
          }
        '';
        description = "Devices to sync with (requires overrideDevices = true)";
      };

      # OPTIONAL: Directories to sync (default: {})
      # Can also be configured via web GUI
      # Requires overrideFolders = true to take effect
      folders = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Path to the folder on this device";
            };
            id = lib.mkOption {
              type = lib.types.str;
              description = "Folder ID (must match on all devices sharing this folder)";
            };
            label = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Human-readable label";
            };
            devices = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "List of device names to share this folder with";
            };
            type = lib.mkOption {
              type = lib.types.enum [ "sendreceive" "sendonly" "receiveonly" ];
              default = "sendreceive";
              description = "Folder type: sendreceive, sendonly, or receiveonly";
            };
          };
        });
        default = {};
        example = lib.literalExpression ''
          {
            documents = {
              path = "/home/user/Documents";
              id = "documents-sync";
              label = "My Documents";
              devices = [ "my-laptop" "my-phone" ];
              type = "sendreceive";
            };
          }
        '';
        description = "Folders to sync (requires overrideFolders = true)";
      };

      # OPTIONAL: Auto-open firewall ports (default: true)
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports for Syncthing";
      };

      # OPTIONAL: Enable relay usage (default: true)
      # Relays help connect when direct connection isn't possible
      relaysEnabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable relay servers for NAT traversal";
      };

      # OPTIONAL: Enable local discovery (default: true)
      # Discovers other Syncthing devices on local network
      localDiscovery = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable local network discovery";
      };

      # OPTIONAL: Enable global discovery (default: true)
      # Discovers devices over the internet
      globalDiscovery = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable global device discovery";
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # ----------------------------------------------------------------------------
    # USER SETUP - Create Syncthing user if using default
    # ----------------------------------------------------------------------------
    users.users = lib.mkIf (cfg.user == "syncthing") {
      syncthing = {
        isSystemUser = true;
        group = cfg.group;
        home = if cfg.dataDir != null then cfg.dataDir else "/var/lib/syncthing";
        createHome = true;
        description = "Syncthing daemon user";
      };
    };

    users.groups = lib.mkIf (cfg.user == "syncthing" && cfg.group == "syncthing") {
      syncthing = {};
    };

    # ----------------------------------------------------------------------------
    # SYNCTHING SERVICE - Configure the built-in NixOS Syncthing module
    # ----------------------------------------------------------------------------
    services.syncthing = {
      enable = true;

      # User and group configuration
      user = cfg.user;
      group = cfg.group;

      # Data directory (main working directory)
      dataDir = if cfg.dataDir != null
                then cfg.dataDir
                else (if cfg.user == "syncthing"
                      then "/var/lib/syncthing"
                      else "/home/${cfg.user}/.config/syncthing");

      # Config directory (where config.xml is stored)
      # If not specified, uses dataDir/.config/syncthing
      configDir = cfg.configDir;

      # Web GUI configuration
      bindIP = "${cfg.bindIP}:${toString cfg.port}";

      # Open firewall ports for sync traffic
      openDefaultPorts = cfg.openFirewall;

      # Override GUI-configured devices and folders
      overrideDevices = cfg.overrideDevices;
      overrideFolders = cfg.overrideFolders;

      # Syncthing settings
      settings = {
        options = {
          # Enable/disable relay servers (help with NAT traversal)
          relaysEnabled = cfg.relaysEnabled;
          # Enable/disable local network discovery
          localAnnounceEnabled = cfg.localDiscovery;
          # Enable/disable global discovery servers
          globalAnnounceEnabled = cfg.globalDiscovery;
          # Enable NAT traversal
          natEnabled = true;
          # Start browser on GUI address change (disabled for servers)
          startBrowser = false;
        };

        # Configure devices if specified
        devices = lib.mapAttrs (name: device: {
          id = device.id;
          addresses = device.addresses;
          introducer = device.introducer;
        }) cfg.devices;

        # Configure folders if specified
        folders = lib.mapAttrs (name: folder: {
          path = folder.path;
          id = folder.id;
          label = if folder.label != "" then folder.label else name;
          devices = folder.devices;
          type = folder.type;
        }) cfg.folders;
      };
    };

    # ----------------------------------------------------------------------------
    # NGINX REVERSE PROXY - Only configured if domain is set
    # ----------------------------------------------------------------------------
    # Enable nginx if domain is configured
    services.nginx.enable = lib.mkIf (cfg.domain != null) true;

    # Configure virtual host for Syncthing
    services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
      ${cfg.domain} = {
        # Force HTTPS if SSL is enabled
        forceSSL = cfg.enableSSL;
        # Get automatic SSL certificate from Let's Encrypt
        enableACME = cfg.enableSSL;

        # Proxy all requests to Syncthing GUI
        locations."/" = {
          proxyPass = "http://${cfg.bindIP}:${toString cfg.port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
          '';
        };
      };
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports
    # ----------------------------------------------------------------------------
    # Open sync ports (22000, 21027) via openDefaultPorts in services.syncthing
    # Open GUI port if binding to non-localhost
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      # Open GUI port if not localhost-only
      lib.optionals (cfg.bindIP != "127.0.0.1") [ cfg.port ]
      # Also open HTTP/HTTPS if using reverse proxy
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );
  };
}

/*
================================================================================
DECLARATIVE VS GUI CONFIGURATION
================================================================================

Understanding overrideDevices and overrideFolders:
---------------------------------------------------

When TRUE (default):
  - Devices/folders in your Nix config are THE source of truth
  - Any changes made in the web GUI will be lost on next rebuild
  - Best for: Production servers, reproducible setups

When FALSE:
  - Web GUI is THE source of truth
  - Nix config is only used for initial setup
  - Changes in GUI persist across rebuilds
  - Best for: Testing, dynamic setups, personal use

Example scenarios:

Fully declarative (recommended for servers):
--------------------------------------------
services.syncthing-custom = {
  enable = true;
  overrideDevices = true;
  overrideFolders = true;
  devices = { / defined here / };
  folders = { / defined here / };
};
# All configuration in Nix, GUI changes ignored


GUI-managed (easier for personal use):
---------------------------------------
services.syncthing-custom = {
  enable = true;
  overrideDevices = false;
  overrideFolders = false;
};
# Configure everything via web GUI, changes persist


Hybrid approach:
----------------
services.syncthing-custom = {
  enable = true;
  overrideDevices = true;   # Devices in Nix
  overrideFolders = false;  # Folders via GUI
  devices = { / defined here / };
};
# Devices locked down, folders flexible


================================================================================
HOW TO GET DEVICE IDs
================================================================================

From Syncthing web GUI:
  Actions → Show ID
  Copy the entire long string (looks like: ABCDEFG-HIJKLMN-...)

From command line:
  sudo -u syncthing syncthing --device-id

From config file:
  cat /var/lib/syncthing/.config/syncthing/config.xml | grep deviceID


================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration (only required options):
----------------------------------------------
services.syncthing-custom = {
  enable = true;  # REQUIRED
};
# This runs Syncthing as the "syncthing" system user
# GUI accessible at: http://localhost:8384


Run as specific user (e.g., your personal user):
-------------------------------------------------
services.syncthing-custom = {
  enable = true;
  user = "myuser";              # Run as this user
  group = "users";              # User's group
  bindIP = "0.0.0.0";      # Allow network access to GUI
};
# GUI accessible at: http://your-ip:8384


Full configuration (all options):
----------------------------------
services.syncthing-custom = {
  enable = true;                # REQUIRED: Turn on the service
  user = "syncthing";           # OPTIONAL: User to run as (default: syncthing)
  group = "syncthing";          # OPTIONAL: Group (default: same as user)
  port = 8384;               # OPTIONAL: Web GUI port (default: 8384)
  bindIP = "0.0.0.0";      # OPTIONAL: GUI bind IP (default: 127.0.0.1)
  dataDir = "/data/syncthing";  # OPTIONAL: Main data directory (default: auto)
  configDir = "/home/user/.config/syncthing";  # OPTIONAL: Config directory (default: null)

  # OPTIONAL: Control whether Nix config overrides GUI settings
  overrideDevices = true;       # Default: true (Nix config takes precedence)
  overrideFolders = true;       # Default: true (Nix config takes precedence)

  # OPTIONAL: Configure devices (requires overrideDevices = true)
  devices = {
    "my-laptop" = {
      id = "ABCDEFG-HIJKLMN-OPQRSTU-VWXYZAB-CDEFGHI-JKLMNOP-QRSTUVW-XYZABCD";
      addresses = [ "dynamic" ];  # or [ "tcp://192.168.1.100:22000" ]
      introducer = false;
    };
    "my-phone" = {
      id = "ANOTHER-DEVICE-ID-GOES-HERE-VERY-LONG-STRING";
      addresses = [ "dynamic" ];
    };
  };

  # OPTIONAL: Configure folders (requires overrideFolders = true)
  folders = {
    documents = {
      path = "/home/user/Documents";
      id = "docs-12345";
      label = "My Documents";
      devices = [ "my-laptop" "my-phone" ];  # Share with these devices
      type = "sendreceive";  # or "sendonly" or "receiveonly"
    };
    photos = {
      path = "/home/user/Photos";
      id = "photos-67890";
      label = "Photo Library";
      devices = [ "my-laptop" ];
      type = "sendreceive";
    };
  };

  # OPTIONAL: Discovery and relay settings
  relaysEnabled = true;         # Default: true
  localDiscovery = true;        # Default: true
  globalDiscovery = true;       # Default: true

  # OPTIONAL: Nginx reverse proxy
  domain = "sync.example.com";  # Default: null (no proxy)
  enableSSL = true;             # Default: false
  openFirewall = true;          # Default: true
};


================================================================================
FIRST-TIME SETUP INSTRUCTIONS
================================================================================

Step 1: Apply your NixOS configuration
---------------------------------------
  sudo nixos-rebuild switch


Step 2: Access Syncthing web GUI
---------------------------------
Local access (default):    http://localhost:8384
Network access:            http://your-ip:8384 (if bindIP = "0.0.0.0")
Domain access:             https://sync.example.com (if configured)


Step 3: Complete initial setup in web GUI
------------------------------------------
1. Set a GUI username and password (IMPORTANT for security!)
   Settings → GUI → Authentication

2. Set a device name
   Actions → Settings → General → Device Name

3. Get your Device ID
   Actions → Show ID
   (You'll need this to connect other devices)


Step 4: Connect other devices
------------------------------
OPTION A: Configure in Nix (declarative, survives rebuilds):

1. On the other device, find its Device ID:
   Actions → Show ID in Syncthing GUI
   Copy the long alphanumeric string

2. Add to your Nix config:
   services.syncthing-custom = {
     enable = true;
     overrideDevices = true;  # Important!
     devices = {
       "laptop" = {
         id = "DEVICE-ID-FROM-OTHER-DEVICE";
       };
     };
     folders = {
       documents = {
         path = "/home/user/Documents";
         id = "docs-sync";
         devices = [ "laptop" ];  # Share with laptop
       };
     };
   };

3. Rebuild: sudo nixos-rebuild switch

4. Accept the connection on the other device


OPTION B: Configure via Web GUI (easier for testing):

1. On other device, add this server's Device ID
2. Accept connection request in this server's web GUI
3. Share folders between devices

⚠️  NOTE: If overrideDevices/overrideFolders are true, GUI changes
    will be overwritten on next rebuild!


================================================================================
WHAT GETS INSTALLED
================================================================================

This module automatically sets up:
- ✓ Syncthing application
- ✓ Syncthing system user (if using default)
- ✓ Configuration and data directories
- ✓ Nginx reverse proxy (if domain is set)
- ✓ Automatic SSL certificates (if enableSSL = true)
- ✓ Firewall rules for sync traffic and GUI (if openFirewall = true)


================================================================================
PORTS USED BY SYNCTHING
================================================================================

TCP 22000:  Sync protocol (encrypted file transfers)
UDP 22000:  QUIC sync protocol
UDP 21027:  Local discovery broadcasts
TCP 8384:   Web GUI (configurable via port)

All sync ports (22000, 21027) are automatically opened if openFirewall = true.


================================================================================
UNDERSTANDING SYNCTHING CONCEPTS
================================================================================

Devices:
--------
Each computer/phone running Syncthing is a "device". Devices are identified
by a unique Device ID (like a fingerprint). You must explicitly share folders
between devices.

Folders:
--------
Folders are directories you want to sync. Each folder has:
- Path: Where files are stored on this device
- Folder ID: Must be identical on all devices sharing this folder
- Label: Human-readable name (can be different per device)

Folder Types:
-------------
- Send & Receive: Full two-way sync (default)
- Send Only: This device only sends changes, doesn't receive
- Receive Only: This device only receives changes, doesn't send

Discovery:
----------
- Local Discovery: Finds devices on your local network automatically
- Global Discovery: Finds devices over internet using discovery servers
- Static IPs: Can also connect by manually entering IP addresses


================================================================================
SECURITY NOTES
================================================================================

⚠️  IMPORTANT: Set GUI authentication immediately!
   Without authentication, anyone who can access the web GUI can:
   - View all your synced files
   - Add/remove devices
   - Change configuration

   Set password in: Settings → GUI → Authentication

🔒 All file transfers are encrypted (TLS 1.3)
   Even without HTTPS on the GUI, file sync is always encrypted.

🌐 Relays are encrypted end-to-end
   Even when using relay servers, only you and the recipient can decrypt files.

🔑 Device IDs are cryptographic certificates
   You must explicitly approve each device connection.


================================================================================
COMMON USE CASES
================================================================================

Personal file sync between computers:
--------------------------------------
services.syncthing-custom = {
  enable = true;
  user = "myuser";
  bindIP = "127.0.0.1";  # Only local access
};


Family file sharing server:
----------------------------
services.syncthing-custom = {
  enable = true;
  user = "syncthing";
  bindIP = "0.0.0.0";    # Allow network access
  folders = {
    family-photos = {
      path = "/mnt/storage/photos";
      id = "family-photos-shared";
      label = "Family Photos";
    };
  };
};


Secure remote access with domain:
----------------------------------
services.syncthing-custom = {
  enable = true;
  domain = "sync.example.com";
  enableSSL = true;
  bindIP = "127.0.0.1";  # Only via reverse proxy
};


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status syncthing

View logs:
  sudo journalctl -u syncthing -f

Check what user Syncthing is running as:
  ps aux | grep syncthing

View current configuration:
  cat /var/lib/syncthing/config.xml

Check firewall ports:
  sudo ss -tulpn | grep -E '(8384|22000|21027)'

Reset to defaults (WARNING: loses all configuration):
  sudo systemctl stop syncthing
  sudo rm -rf /var/lib/syncthing/.config/syncthing/*
  sudo systemctl start syncthing

Check folder permissions:
  ls -la /path/to/synced/folder
  # Folder must be readable/writable by the Syncthing user


================================================================================
MOBILE APP SETUP
================================================================================

Android:
  Install "Syncthing" from F-Droid or Google Play
  Add device ID from your server
  Accept connection on server's web GUI
  Share folders

iOS:
  Install "Möbius Sync" from App Store
  Add device ID from your server
  Accept connection on server's web GUI
  Share folders

*/
