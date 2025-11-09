{ config, lib, pkgs, ... }:

let
  cfg = config.services.nodered-service;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.nodered-service = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Node-RED service";

      # OPTIONAL: Port to listen on (default: 1880)
      port = lib.mkOption {
        type = lib.types.port;
        default = 1880;
        description = "Port for Node-RED to listen on";
      };

      # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
      # Use "0.0.0.0" for access from other devices
      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
      };

      # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "nodered.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      # Only works if domain is set
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      # OPTIONAL: Where to store Node-RED flows and data (default: /var/lib/node-red)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/node-red";
        example = "/data/node-red";
        description = "Directory for Node-RED flows and configuration";
      };

      # OPTIONAL: Auto-open firewall ports (default: false)
      # Set to true if accessing from other devices
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open firewall ports";
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # ----------------------------------------------------------------------------
    # DIRECTORY SETUP - Create necessary directories with proper permissions
    # ----------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      # Create data directory for Node-RED flows and configuration
      "d ${cfg.dataDir} 0750 node-red node-red -"
    ];

    # ----------------------------------------------------------------------------
    # USER SETUP - Create dedicated system user for Node-RED
    # ----------------------------------------------------------------------------
    users.users.node-red = {
      isSystemUser = true;
      group = "node-red";
      home = cfg.dataDir;
    };

    users.groups.node-red = {};

    # ----------------------------------------------------------------------------
    # NODE-RED SERVICE - Configure the systemd service
    # ----------------------------------------------------------------------------
    systemd.services.node-red = {
      description = "Node-RED Flow-based Programming";
      # Start automatically on boot
      wantedBy = [ "multi-user.target" ];
      # Start after network is available
      after = [ "network.target" ];

      # Make Node.js available to the service
      path = with pkgs; [ nodejs ];

      serviceConfig = {
        Type = "simple";
        User = "node-red";
        Group = "node-red";
        WorkingDirectory = cfg.dataDir;
        # Start Node-RED with specified settings
        ExecStart = "${pkgs.nodePackages.node-red}/bin/node-red --userDir ${cfg.dataDir} --port ${toString cfg.port}";
        # Restart on failure
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;      # Prevent privilege escalation
        PrivateTmp = true;            # Use private /tmp directory
        ProtectSystem = "strict";     # Make most of filesystem read-only
        ProtectHome = true;           # Make /home inaccessible
        ReadWritePaths = [ cfg.dataDir ];  # Only allow writes to data directory
      };
    };

    # ----------------------------------------------------------------------------
    # NGINX REVERSE PROXY - Only configured if domain is set
    # ----------------------------------------------------------------------------
    # Enable nginx if domain is configured
    services.nginx.enable = lib.mkIf (cfg.domain != null) true;

    # Configure virtual host for Node-RED
    services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
      ${cfg.domain} = {
        # Force HTTPS if SSL is enabled
        forceSSL = cfg.enableSSL;
        # Get automatic SSL certificate from Let's Encrypt
        enableACME = cfg.enableSSL;

        # Proxy all requests to Node-RED
        locations."/" = {
          proxyPass = "http://${cfg.bindIP}:${toString cfg.port}";
          # Enable WebSocket support (required for Node-RED editor)
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            # Longer timeout for long-running flows
            proxy_read_timeout 300s;
          '';
        };
      };
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      # Always open the Node-RED port
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
services.nodered-service = {
  enable = true;  # REQUIRED
};


Full configuration (all options):
----------------------------------
services.nodered-service = {
  enable = true;                # REQUIRED: Turn on the service
  port = 1880;                  # OPTIONAL: Default is 1880
  bindIP = "0.0.0.0";          # OPTIONAL: Default is 127.0.0.1 (localhost only)
  dataDir = "/data/node-red";   # OPTIONAL: Default is /var/lib/node-red

  # OPTIONAL: Nginx reverse proxy
  domain = "nodered.example.com";  # Default is null (no proxy)
  enableSSL = true;                # Default is false
  openFirewall = true;             # Default is false
};


================================================================================
FIRST-TIME SETUP INSTRUCTIONS
================================================================================

Step 1: Apply your NixOS configuration
---------------------------------------
  sudo nixos-rebuild switch


Step 2: Access Node-RED editor
-------------------------------
Local access:     http://127.0.0.1:1880
Network access:   http://your-ip:1880
Domain access:    https://nodered.example.com (if configured)


Step 3: Secure the editor (IMPORTANT!)
---------------------------------------
By default, Node-RED has NO authentication. Anyone who can access the editor
can deploy flows and execute code on your server.

To add authentication, edit: /var/lib/node-red/settings.js

Find the "adminAuth" section and uncomment it, then set a password:

  1. Generate password hash:
     node-red admin hash-pw

  2. Edit settings.js and add:
     adminAuth: {
       type: "credentials",
       users: [{
         username: "admin",
         password: "$2b$08$...",  // Your generated hash
         permissions: "*"
       }]
     }

  3. Restart Node-RED:
     sudo systemctl restart node-red


================================================================================
WHAT GETS INSTALLED
================================================================================

This module automatically sets up:
- ✓ Node-RED application
- ✓ Node.js runtime
- ✓ Nginx reverse proxy (if domain is set)
- ✓ Automatic SSL certificates (if enableSSL = true)
- ✓ Firewall rules (if openFirewall = true)
- ✓ System user and directories


================================================================================
INSTALLING NODE-RED NODES
================================================================================

Node-RED uses npm packages called "nodes" to add functionality.

Install nodes via the Palette Manager (in Node-RED UI):
  1. Click menu (☰) → Manage palette
  2. Go to "Install" tab
  3. Search for nodes (e.g., "node-red-dashboard")
  4. Click Install

Or install manually:
  sudo -u node-red npm install --prefix /var/lib/node-red node-red-dashboard
  sudo systemctl restart node-red

Popular nodes to install:
  - node-red-dashboard           # Create web dashboards
  - node-red-contrib-home-assistant-websocket  # Home Assistant integration
  - node-red-contrib-telegrambot # Telegram bot
  - node-red-contrib-influxdb    # InfluxDB database
  - node-red-contrib-bigtimer    # Advanced scheduling


================================================================================
INTEGRATING WITH HOME ASSISTANT
================================================================================

To connect Node-RED with Home Assistant:

1. Install the Home Assistant node:
   Menu → Manage palette → Install → search "home-assistant-websocket"

2. In Home Assistant, create a Long-Lived Access Token:
   Profile → Security → Long-Lived Access Tokens → Create Token

3. In Node-RED, add a "server" node:
   - Base URL: http://your-home-assistant:8123
   - Access Token: [paste your token]


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status node-red

View logs:
  sudo journalctl -u node-red -f

Check if port is open:
  sudo ss -tulpn | grep 1880

Access flows file directly:
  cat /var/lib/node-red/flows.json

Reset to defaults (WARNING: deletes all flows):
  sudo systemctl stop node-red
  sudo rm -rf /var/lib/node-red/*
  sudo systemctl start node-red

*/
