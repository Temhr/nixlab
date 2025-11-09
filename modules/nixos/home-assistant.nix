{ config, lib, pkgs, ... }:

let
  cfg = config.services.homeassistant-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.homeassistant-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Home Assistant service";

      # OPTIONAL: Port to listen on (default: 8123)
      port = lib.mkOption {
        type = lib.types.port;
        default = 8123;
        description = "Port for Home Assistant to listen on";
      };

      # OPTIONAL: IP to bind to (default: 0.0.0.0 = all interfaces)
      # Home Assistant typically needs network access for IoT devices
      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1"; #localhost only
        description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
      };

      # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "home.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      # Only works if domain is set
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      # OPTIONAL: Where to store Home Assistant data (default: /var/lib/hass)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/hass";
        example = "/data/homeassistant";
        description = "Directory for Home Assistant configuration and data";
      };

      # OPTIONAL: List of integration components to enable (default: [])
      # Examples: "met" (weather), "esphome", "mqtt", "google_assistant"
      extraComponents = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "met" "esphome" "mqtt" ];
        description = "List of Home Assistant integration components to enable";
      };

      # OPTIONAL: Extra Python packages for custom integrations (default: none)
      extraPackages = lib.mkOption {
        type = lib.types.functionTo (lib.types.listOf lib.types.package);
        default = ps: [];
        example = lib.literalExpression "ps: with ps; [ numpy pandas ]";
        description = "Extra Python packages to make available to Home Assistant";
      };

      # OPTIONAL: Auto-open firewall ports (default: true)
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports";
      };

      # OPTIONAL: Your home's latitude (default: 45.0)
      latitude = lib.mkOption {
        type = lib.types.float;
        default = 45.0;
        description = "Latitude for your home location";
      };

      # OPTIONAL: Your home's longitude (default: -75.0)
      longitude = lib.mkOption {
        type = lib.types.float;
        default = -75.0;
        description = "Longitude for your home location";
      };

      # OPTIONAL: Your timezone (default: America/Toronto)
      timeZone = lib.mkOption {
        type = lib.types.str;
        default = "America/Toronto";
        example = "Europe/London";
        description = "Time zone for Home Assistant";
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # ----------------------------------------------------------------------------
    # HOME ASSISTANT SERVICE - Configure the built-in NixOS Home Assistant module
    # ----------------------------------------------------------------------------
    services.home-assistant = {
      enable = true;

      # Install additional integration components
      extraComponents = cfg.extraComponents;

      # Add extra Python packages for custom integrations
      extraPackages = cfg.extraPackages;

      # Home Assistant configuration (configuration.yaml equivalent)
      config = {
        # Enable default integrations (UI, mobile app, etc.)
        default_config = {};

        # HTTP server configuration
        http = {
          # IP address to listen on
          server_host = cfg.bindIP;
          # Port to listen on
          server_port = cfg.port;
        } // lib.optionalAttrs (cfg.domain != null) {
          # If using reverse proxy, trust forwarded headers
          use_x_forwarded_for = true;
          trusted_proxies = [ "127.0.0.1" ];
        };

        # Home location and preferences
        homeassistant = {
          name = "Home";
          latitude = cfg.latitude;
          longitude = cfg.longitude;
          elevation = 0;
          unit_system = "metric";
          time_zone = cfg.timeZone;
        };
      };
    };

    # ----------------------------------------------------------------------------
    # CUSTOM DATA DIRECTORY - Override default if specified
    # ----------------------------------------------------------------------------
    systemd.services.home-assistant = lib.mkIf (cfg.dataDir != "/var/lib/hass") {
      serviceConfig = {
        # Clear the default state directory
        StateDirectory = lib.mkForce "";
        # Use custom working directory instead
        WorkingDirectory = lib.mkForce cfg.dataDir;
      };
    };

    # Create custom data directory with proper permissions
    systemd.tmpfiles.rules = lib.mkIf (cfg.dataDir != "/var/lib/hass") [
      "d ${cfg.dataDir} 0750 hass hass -"
    ];

    # ----------------------------------------------------------------------------
    # NGINX REVERSE PROXY - Only configured if domain is set
    # ----------------------------------------------------------------------------
    # Enable nginx if domain is configured
    services.nginx.enable = lib.mkIf (cfg.domain != null) true;

    # Configure virtual host for Home Assistant
    services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
      ${cfg.domain} = {
        # Force HTTPS if SSL is enabled
        forceSSL = cfg.enableSSL;
        # Get automatic SSL certificate from Let's Encrypt
        enableACME = cfg.enableSSL;

        # Proxy all requests to Home Assistant
        locations."/" = {
          proxyPass = "http://${cfg.bindIP}:${toString cfg.port}";
          # Enable WebSocket support (required for real-time updates)
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
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      # Always open the Home Assistant port
      [ cfg.port ]
      # Also open HTTP (80) and HTTPS (443) if using domain
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );
  };
}

/*
================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration (only required options):
----------------------------------------------
services.homeassistant-custom = {
  enable = true;  # REQUIRED
};


Full configuration (all options):
----------------------------------
services.homeassistant-custom = {
  enable = true;                    # REQUIRED: Turn on the service
  port = 8123;                      # OPTIONAL: Default is 8123
  bindIP = "0.0.0.0";              # OPTIONAL: Default is 0.0.0.0
  dataDir = "/data/homeassistant";  # OPTIONAL: Default is /var/lib/hass

  # OPTIONAL: Your home's location (used for sun/weather)
  latitude = 45.4215;
  longitude = -75.6972;
  timeZone = "America/Toronto";

  # OPTIONAL: Add integration components
  extraComponents = [
    "met"           # Weather forecasts
    "esphome"       # ESPHome devices
    "mqtt"          # MQTT broker
    "google_assistant"
  ];

  # OPTIONAL: Add extra Python packages
  extraPackages = ps: with ps; [
    numpy           # For data processing
    pillow          # For image manipulation
  ];

  # OPTIONAL: Nginx reverse proxy
  domain = "home.example.com";      # Default is null (no proxy)
  enableSSL = true;                 # Default is false
  openFirewall = true;              # Default is true
};


================================================================================
FIRST-TIME SETUP INSTRUCTIONS
================================================================================

Step 1: Apply your NixOS configuration
---------------------------------------
  sudo nixos-rebuild switch


Step 2: Access Home Assistant
------------------------------
Visit: http://your-ip:8123
(or https://home.example.com if you configured a domain)


Step 3: Complete onboarding wizard
-----------------------------------
On first access, Home Assistant will guide you through:
- Creating an admin account
- Setting up your home location
- Connecting devices and services


================================================================================
WHAT GETS INSTALLED
================================================================================

This module automatically sets up:
- ✓ Home Assistant core application
- ✓ All requested integration components
- ✓ Extra Python packages (if specified)
- ✓ Nginx reverse proxy (if domain is set)
- ✓ Automatic SSL certificates (if enableSSL = true)
- ✓ Firewall rules (if openFirewall = true)
- ✓ System user and directories


================================================================================
ADDING INTEGRATIONS
================================================================================

Common integration components to add to extraComponents:

IoT Platforms:
  - "esphome"         # ESPHome devices
  - "mqtt"            # MQTT broker
  - "zwave_js"        # Z-Wave devices
  - "zha"             # Zigbee devices

Cloud Services:
  - "google_assistant"
  - "alexa"
  - "spotify"
  - "google_translate"

Weather & Location:
  - "met"             # Weather forecasts
  - "sun"             # Sun position (auto-included in default_config)

Media:
  - "plex"
  - "sonos"
  - "cast"            # Chromecast


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status home-assistant

View logs:
  sudo journalctl -u home-assistant -f

Check configuration:
  sudo -u hass hass --script check_config --config /var/lib/hass

Access via local network:
  http://192.168.x.x:8123

*/
