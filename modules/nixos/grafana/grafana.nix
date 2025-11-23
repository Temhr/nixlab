{ config, lib, pkgs, ... }:

let
  cfg = config.services.grafana-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.grafana-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Grafana monitoring and visualization platform";

      # OPTIONAL: Port to listen on (default: 3100)
      port = lib.mkOption {
        type = lib.types.port;
        default = 3100;
        description = "Port for Grafana to listen on";
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
        example = "grafana.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      # Only works if domain is set
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      # OPTIONAL: Where to store Grafana data (default: /var/lib/grafana)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/grafana";
        example = "/data/grafana";
        description = "Directory for Grafana data and databases";
      };

      # OPTIONAL: Grafana package to use (default: pkgs.grafana)
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.grafana;
        defaultText = lib.literalExpression "pkgs.grafana";
        description = "The Grafana package to use";
      };

      # OPTIONAL: Auto-open firewall ports (default: true)
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports";
      };

      # OPTIONAL: Allow anonymous access (default: false)
      allowAnonymous = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow anonymous read-only access to dashboards";
      };

      # OPTIONAL: Default admin password (default: admin)
      # IMPORTANT: Change this on first login!
      adminPassword = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Initial admin password (change after first login!)";
      };

      # ┌─────────────────────────────────────────────────────────┐
      # │ NEW: MULTIPLE DASHBOARDS SUPPORT                        │
      # └─────────────────────────────────────────────────────────┘
      dashboards = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.path;
              description = "Path to the dashboard JSON file";
              example = ./my-dashboard.json;
            };

            folder = lib.mkOption {
              type = lib.types.str;
              default = "General";
              description = "Grafana folder to place this dashboard in";
              example = "System Monitoring";
            };

            editable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Allow editing this dashboard in the UI";
            };

            updateInterval = lib.mkOption {
              type = lib.types.int;
              default = 10;
              description = "How often to check for updates (seconds)";
            };
          };
        });
        default = {};
        description = ''
          Dashboards to provision. Each dashboard needs a unique name.
          Example:
            dashboards = {
              maintenance = {
                path = ./maintenance-dashboard.json;
                folder = "Maintenance";
              };
              system-overview = {
                path = ./system-overview.json;
                folder = "System";
              };
            };
        '';
        example = lib.literalExpression ''
          {
            maintenance = {
              path = ./maintenance-dashboard.json;
              folder = "Maintenance";
              editable = true;
            };
            node-exporter = {
              path = ./node-exporter.json;
              folder = "System Monitoring";
              editable = false;
            };
          }
        '';
      };

      # ┌─────────────────────────────────────────────────────────┐
      # │ LEGACY: Maintain backward compatibility                │
      # └─────────────────────────────────────────────────────────┘
      maintenance = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "DEPRECATED: Use dashboards option instead. Enable maintenance monitoring dashboard";
        };

        dashboardPath = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "DEPRECATED: Use dashboards option instead";
        };

        provisionPath = lib.mkOption {
          type = lib.types.str;
          default = "${cfg.dataDir}/dashboards/maintenance";
          description = "DEPRECATED: Path where maintenance dashboard will be provisioned";
        };
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # Convert legacy maintenance option to new dashboards format
    services.grafana-custom.dashboards = lib.mkIf (cfg.maintenance.enable && cfg.maintenance.dashboardPath != null) {
      maintenance = {
        path = cfg.maintenance.dashboardPath;
        folder = "Maintenance";
        editable = true;
      };
    };

    # ----------------------------------------------------------------------------
    # DIRECTORY SETUP - Create necessary directories with proper permissions
    # ----------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 grafana grafana -"
      "d ${cfg.dataDir}/data 0750 grafana grafana -"
      "d ${cfg.dataDir}/logs 0750 grafana grafana -"
      "d ${cfg.dataDir}/plugins 0750 grafana grafana -"
      "d ${cfg.dataDir}/dashboards 0755 grafana grafana -"
    ] ++ lib.flatten (lib.mapAttrsToList (name: dashboard: [
      "d ${cfg.dataDir}/dashboards/${name} 0755 grafana grafana -"
    ]) cfg.dashboards);

    # ----------------------------------------------------------------------------
    # USER SETUP - Create dedicated system user for Grafana
    # ----------------------------------------------------------------------------
    users.users.grafana = {
      isSystemUser = true;
      group = "grafana";
      home = cfg.dataDir;
      description = "Grafana service user";
    };

    users.groups.grafana = {};

    users.users.temhr.extraGroups = [ "grafana" ];

    # ----------------------------------------------------------------------------
    # GRAFANA SERVICE - Configure the systemd service
    # ----------------------------------------------------------------------------
    systemd.services.grafana = {
      description = "Grafana Monitoring and Visualization Platform";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        GF_PATHS_DATA = "${cfg.dataDir}/data";
        GF_PATHS_LOGS = "${cfg.dataDir}/logs";
        GF_PATHS_PLUGINS = "${cfg.dataDir}/plugins";
        GF_PATHS_PROVISIONING = "${cfg.dataDir}/provisioning";
        GF_SERVER_HTTP_PORT = toString cfg.port;
        GF_SERVER_HTTP_ADDR = cfg.bindIP;
        GF_SERVER_DOMAIN = if cfg.domain != null then cfg.domain else "localhost";
        GF_SERVER_ROOT_URL = if cfg.domain != null
          then "${if cfg.enableSSL then "https" else "http"}://${cfg.domain}/"
          else "http://localhost:${toString cfg.port}/";
        GF_SECURITY_ADMIN_PASSWORD = cfg.adminPassword;
        GF_AUTH_ANONYMOUS_ENABLED = lib.boolToString cfg.allowAnonymous;
        GF_AUTH_ANONYMOUS_ORG_ROLE = "Viewer";
        GF_DATABASE_TYPE = "sqlite3";
        GF_DATABASE_PATH = "${cfg.dataDir}/data/grafana.db";
      };

      serviceConfig = {
        Type = "simple";
        User = "grafana";
        Group = "grafana";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/grafana server --config=${cfg.dataDir}/grafana.ini --homepath=${cfg.package}/share/grafana";
        Restart = "on-failure";
        RestartSec = "10s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };

      preStart = ''
        # Create minimal config if it doesn't exist
        if [ ! -f ${cfg.dataDir}/grafana.ini ]; then
          cat > ${cfg.dataDir}/grafana.ini << EOF
# Grafana Configuration
[paths]
data = ${cfg.dataDir}/data
logs = ${cfg.dataDir}/logs
plugins = ${cfg.dataDir}/plugins
provisioning = ${cfg.dataDir}/provisioning

[server]
http_port = ${toString cfg.port}
http_addr = ${cfg.bindIP}
domain = ${if cfg.domain != null then cfg.domain else "localhost"}
root_url = ${if cfg.domain != null
  then "${if cfg.enableSSL then "https" else "http"}://${cfg.domain}/"
  else "http://localhost:${toString cfg.port}/"}

[database]
type = sqlite3
path = ${cfg.dataDir}/data/grafana.db

[security]
admin_password = ${cfg.adminPassword}

[auth.anonymous]
enabled = ${lib.boolToString cfg.allowAnonymous}
org_role = Viewer

[log]
mode = console file
level = info
EOF
          chown grafana:grafana ${cfg.dataDir}/grafana.ini
          chmod 660 ${cfg.dataDir}/grafana.ini
        fi

        # Set up provisioning directories
        mkdir -p ${cfg.dataDir}/provisioning/{dashboards,datasources,notifiers}
        chown -R grafana:grafana ${cfg.dataDir}/provisioning

        # ┌─────────────────────────────────────────────────────────┐
        # │ PROVISION ALL DASHBOARDS                                │
        # └─────────────────────────────────────────────────────────┘
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: dashboard: ''
          # Setup dashboard: ${name}
          mkdir -p ${cfg.dataDir}/dashboards/${name}
          chown grafana:grafana ${cfg.dataDir}/dashboards/${name}

          # Copy dashboard JSON if it exists
          if [ -f ${dashboard.path} ]; then
            install -m 644 -o grafana -g grafana ${dashboard.path} ${cfg.dataDir}/dashboards/${name}/dashboard.json
          else
            echo "Warning: Dashboard file not found: ${dashboard.path}"
          fi

          # Create dashboard provisioning config
          cat > ${cfg.dataDir}/provisioning/dashboards/${name}.yaml << 'DASHEOF'
apiVersion: 1

providers:
  - name: '${name}'
    orgId: 1
    folder: '${dashboard.folder}'
    type: file
    disableDeletion: false
    updateIntervalSeconds: ${toString dashboard.updateInterval}
    allowUiUpdates: ${lib.boolToString dashboard.editable}
    options:
      path: ${cfg.dataDir}/dashboards/${name}
      foldersFromFilesStructure: false
DASHEOF
          chown grafana:grafana ${cfg.dataDir}/provisioning/dashboards/${name}.yaml
        '') cfg.dashboards)}
      '';
    };

    # ┌─────────────────────────────────────────────────────────┐
    # │ ACTIVATION SCRIPT - Copy dashboards on system rebuild  │
    # └─────────────────────────────────────────────────────────┘
    system.activationScripts.grafana-dashboards = lib.mkIf (cfg.dashboards != {}) ''
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: dashboard: ''
        if [ -f ${dashboard.path} ]; then
          mkdir -p ${cfg.dataDir}/dashboards/${name}
          install -m 644 ${dashboard.path} ${cfg.dataDir}/dashboards/${name}/dashboard.json
          chown -R grafana:grafana ${cfg.dataDir}/dashboards/${name}
        fi
      '') cfg.dashboards)}
    '';

    # ----------------------------------------------------------------------------
    # NGINX REVERSE PROXY - Only configured if domain is set
    # ----------------------------------------------------------------------------
    services.nginx.enable = lib.mkIf (cfg.domain != null) true;

    services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
      ${cfg.domain} = {
        forceSSL = cfg.enableSSL;
        enableACME = cfg.enableSSL;

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
            proxy_buffer_size 128k;
            proxy_buffers 4 256k;
            proxy_busy_buffers_size 256k;
          '';
        };
      };
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      lib.optionals (cfg.domain == null) [ cfg.port ]
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );
  };
}

/*
================================================================================
MULTIPLE DASHBOARDS USAGE
================================================================================

Basic example with multiple dashboards:
---------------------------------------
services.grafana-custom = {
  enable = true;

  dashboards = {
    # System maintenance dashboard
    maintenance = {
      path = ./dashboards/maintenance.json;
      folder = "Maintenance";
      editable = true;
    };

    # Node exporter system overview
    system-overview = {
      path = ./dashboards/node-system-overview.json;
      folder = "System Monitoring";
      editable = true;
    };

    # Docker monitoring
    docker = {
      path = ./dashboards/docker-monitoring.json;
      folder = "Containers";
      editable = false;  # Prevent UI modifications
      updateInterval = 30;  # Check for updates every 30 seconds
    };

    # Network monitoring
    network = {
      path = ./dashboards/network-stats.json;
      folder = "Network";
    };

    # Application metrics
    app-metrics = {
      path = ./dashboards/app-metrics.json;
      folder = "Applications";
    };
  };
};


Advanced example with organization:
------------------------------------
services.grafana-custom = {
  enable = true;
  port = 3100;
  bindIP = "0.0.0.0";
  domain = "grafana.example.com";
  enableSSL = true;

  dashboards = {
    # Infrastructure folder
    infra-cpu = {
      path = ./dashboards/infrastructure/cpu-metrics.json;
      folder = "Infrastructure";
    };
    infra-memory = {
      path = ./dashboards/infrastructure/memory-metrics.json;
      folder = "Infrastructure";
    };
    infra-disk = {
      path = ./dashboards/infrastructure/disk-metrics.json;
      folder = "Infrastructure";
    };

    # Application folder
    app-frontend = {
      path = ./dashboards/apps/frontend.json;
      folder = "Applications";
    };
    app-backend = {
      path = ./dashboards/apps/backend.json;
      folder = "Applications";
    };
    app-database = {
      path = ./dashboards/apps/database.json;
      folder = "Applications";
    };

    # Security folder
    security-firewall = {
      path = ./dashboards/security/firewall-logs.json;
      folder = "Security";
      editable = false;  # Lock down security dashboards
    };
    security-intrusion = {
      path = ./dashboards/security/ids.json;
      folder = "Security";
      editable = false;
    };
  };
};


Directory structure example:
----------------------------
/etc/nixos/
├── configuration.nix
├── modules/
│   └── grafana/
│       ├── grafana.nix
│       └── dashboards/
│           ├── maintenance.json
│           ├── node-system-overview.json
│           ├── infrastructure/
│           │   ├── cpu-metrics.json
│           │   ├── memory-metrics.json
│           │   └── disk-metrics.json
│           └── apps/
│               ├── frontend.json
│               └── backend.json


Organizing dashboards by source:
---------------------------------
services.grafana-custom = {
  enable = true;

  dashboards = {
    # Custom dashboards
    custom-maintenance = {
      path = ./custom/maintenance.json;
      folder = "Custom";
    };

    # Community dashboards (downloaded from grafana.com)
    community-node-exporter = {
      path = ./community/node-exporter-1860.json;
      folder = "Community";
      editable = false;  # Prevent changes to community dashboards
    };

    # Team-specific dashboards
    team-devops = {
      path = ./teams/devops-overview.json;
      folder = "DevOps Team";
    };
    team-sre = {
      path = ./teams/sre-dashboard.json;
      folder = "SRE Team";
    };
  };
};


================================================================================
DASHBOARD MANAGEMENT
================================================================================

Adding a new dashboard:
-----------------------
1. Export your dashboard from Grafana UI (Share → Export → Save to file)
2. Save it to your dashboards directory
3. Add it to your configuration:

   dashboards.my-new-dashboard = {
     path = ./dashboards/my-new-dashboard.json;
     folder = "My Folder";
   };

4. Rebuild: sudo nixos-rebuild switch


Updating a dashboard:
---------------------
1. Make changes in Grafana UI (if editable = true)
2. Export the updated dashboard
3. Replace the JSON file
4. Rebuild: sudo nixos-rebuild switch
   (Or wait for updateInterval seconds)


Removing a dashboard:
---------------------
1. Remove the dashboard from your configuration
2. Rebuild: sudo nixos-rebuild switch
3. The dashboard files remain but won't be provisioned


Importing community dashboards:
--------------------------------
1. Find dashboard at https://grafana.com/grafana/dashboards/
2. Download JSON (or copy ID)
3. Save to your dashboards directory
4. Add to configuration:

   dashboards.node-exporter-full = {
     path = ./community/dashboard-1860.json;
     folder = "Community";
     editable = false;
   };


================================================================================
DASHBOARD OPTIONS EXPLAINED
================================================================================

path:
  - Required: Path to the dashboard JSON file
  - Can be relative (./dashboards/file.json) or absolute
  - File is copied to /var/lib/grafana/dashboards/<name>/

folder:
  - Optional: Grafana folder to organize dashboards
  - Default: "General"
  - Creates folders automatically if they don't exist
  - All dashboards with same folder name are grouped

editable:
  - Optional: Allow editing in Grafana UI
  - Default: true
  - Set to false for:
    * Community dashboards you don't want to modify
    * Production dashboards that should be version controlled
    * Security/compliance dashboards

updateInterval:
  - Optional: How often Grafana checks for file changes (seconds)
  - Default: 10
  - Lower = faster updates, higher = less resource usage
  - Useful range: 5-60 seconds


================================================================================
TIPS AND BEST PRACTICES
================================================================================

1. Organization:
   - Use clear, descriptive dashboard names
   - Group related dashboards in same folder
   - Prefix names with category: "infra-", "app-", "sec-"

2. Version Control:
   - Keep dashboard JSONs in git
   - Use meaningful commit messages when updating
   - Tag stable dashboard versions

3. Editable Settings:
   - Development: editable = true (easy iteration)
   - Production: editable = false (controlled changes)
   - Team dashboards: editable = true (collaborative)

4. File Naming:
   - Use kebab-case: my-dashboard.json
   - Include purpose: node-exporter-full.json
   - Version if needed: app-metrics-v2.json

5. Testing:
   - Test new dashboards in Grafana UI first
   - Export when satisfied
   - Then add to configuration

6. Performance:
   - Don't provision 100+ dashboards at once
   - Use longer updateInterval for large deployments
   - Consider dashboard pagination in UI


================================================================================
TROUBLESHOOTING
================================================================================

Dashboard not appearing:
  1. Check file exists: ls -la /var/lib/grafana/dashboards/<name>/
  2. Check permissions: Should be owned by grafana:grafana
  3. Check provisioning config: cat /var/lib/grafana/provisioning/dashboards/<name>.yaml
  4. Restart service: sudo systemctl restart grafana
  5. Check logs: sudo journalctl -u grafana -f

Dashboard not updating:
  1. Verify file changed: stat /var/lib/grafana/dashboards/<name>/dashboard.json
  2. Wait for updateInterval seconds
  3. Or restart: sudo systemctl restart grafana

Folder not created:
  - Folders are created automatically on first dashboard load
  - Check spelling matches exactly
  - Try restarting Grafana

Multiple dashboards in wrong folder:
  - Verify folder name is exactly the same (case-sensitive)
  - Check YAML files for correct folder setting

Permission errors:
  sudo chown -R grafana:grafana /var/lib/grafana/dashboards/
  sudo chmod -R 755 /var/lib/grafana/dashboards/
*/
