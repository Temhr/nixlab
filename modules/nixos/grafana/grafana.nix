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
      # │ NEW: MAINTENANCE MONITORING OPTIONS                     │
      # └─────────────────────────────────────────────────────────┘
      maintenance = {
        enable = lib.mkEnableOption "maintenance monitoring dashboard";

        dashboardPath = lib.mkOption {
          type = lib.types.path;
          default = ./grafana-maintenance-dashboard.json;
          description = "Path to maintenance dashboard JSON file";
        };

        provisionPath = lib.mkOption {
          type = lib.types.str;
          default = "${cfg.dataDir}/dashboards/maintenance";
          description = "Path where maintenance dashboard will be provisioned";
        };
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
      "d ${cfg.dataDir} 0750 grafana grafana -"
      "d ${cfg.dataDir}/data 0750 grafana grafana -"
      "d ${cfg.dataDir}/logs 0750 grafana grafana -"
      "d ${cfg.dataDir}/plugins 0750 grafana grafana -"
    ] ++ lib.optionals cfg.maintenance.enable [
      "d ${cfg.maintenance.provisionPath} 0755 grafana grafana -"
    ];

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

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };

      # Ensure config file exists
      preStart = ''
        # Create minimal config if it doesn't exist
        if [ ! -f ${cfg.dataDir}/grafana.ini ]; then
          cat > ${cfg.dataDir}/grafana.ini << EOF
# Grafana Configuration
# Most settings are controlled via environment variables

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

        ${lib.optionalString cfg.maintenance.enable ''
          # Provision maintenance dashboard
          mkdir -p ${cfg.maintenance.provisionPath}

          # Copy dashboard JSON if it exists
          if [ -f ${cfg.maintenance.dashboardPath} ]; then
            cp ${cfg.maintenance.dashboardPath} ${cfg.maintenance.provisionPath}/maintenance.json
            chown grafana:grafana ${cfg.maintenance.provisionPath}/maintenance.json
          fi

          # Create dashboard provisioning config
          cat > ${cfg.dataDir}/provisioning/dashboards/maintenance.yaml << EOF
apiVersion: 1

providers:
  - name: 'Maintenance'
    orgId: 1
    folder: 'Maintenance'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: ${cfg.maintenance.provisionPath}
      foldersFromFilesStructure: false
EOF
          chown grafana:grafana ${cfg.dataDir}/provisioning/dashboards/maintenance.yaml

          # Create datasource provisioning if Prometheus/Loki are enabled
          cat > ${cfg.dataDir}/provisioning/datasources/default.yaml << EOF
apiVersion: 1

datasources:
  ${lib.optionalString config.services.prometheus-custom.enable ''
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:${toString config.services.prometheus-custom.port}
    isDefault: true
    jsonData:
      timeInterval: 15s
  ''}
  ${lib.optionalString config.services.loki-custom.enable ''
  - name: Loki
    type: loki
    access: proxy
    url: http://localhost:${toString config.services.loki-custom.port}
    jsonData:
      maxLines: 1000
  ''}
EOF
          chown grafana:grafana ${cfg.dataDir}/provisioning/datasources/default.yaml
        ''}
      '';
    };

    # ┌─────────────────────────────────────────────────────────┐
    # │ ACTIVATION SCRIPT - Copy dashboard on system rebuild   │
    # └─────────────────────────────────────────────────────────┘
    system.activationScripts.grafana-maintenance-dashboard = lib.mkIf cfg.maintenance.enable ''
      if [ -f ${cfg.maintenance.dashboardPath} ]; then
        mkdir -p ${cfg.maintenance.provisionPath}
        cp ${cfg.maintenance.dashboardPath} ${cfg.maintenance.provisionPath}/maintenance.json
        chown -R grafana:grafana ${cfg.maintenance.provisionPath}
      fi
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

            # Required for Grafana Live and streaming
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";

            # Increase buffer sizes for large dashboards
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
      # Open Grafana port if not using reverse proxy
      lib.optionals (cfg.domain == null) [ cfg.port ]
      # Open HTTP/HTTPS if using reverse proxy
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );
  };
}

/*
================================================================================
MAINTENANCE DASHBOARD USAGE
================================================================================

Enable maintenance dashboard:
------------------------------
services.grafana-custom = {
  enable = true;

  # Enable maintenance dashboard
  maintenance = {
    enable = true;
    dashboardPath = ./grafana-maintenance-dashboard.json;
  };
};

This will:
  - Auto-provision the maintenance dashboard on startup
  - Create a "Maintenance" folder in Grafana
  - Auto-configure Prometheus and Loki datasources if enabled
  - Dashboard updates automatically on nixos-rebuild

Access the dashboard:
  1. Login to Grafana
  2. Navigate to Dashboards
  3. Find "Maintenance" folder
  4. Open "System Maintenance Checklist" dashboard

The dashboard will show:
  - Health score gauge
  - Active alerts by severity
  - Resource utilization graphs
  - Alert tables by checklist section
  - Manual task checklists
  - Certificate expiry timeline
  - Service uptime matrix
  - Maintenance task completion stats

*/

/*
================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration:
----------------------
services.grafana-custom = {
  enable = true;
};
# Access at: http://your-ip:3100
# Default login: admin / admin


Full configuration with domain:
--------------------------------
services.grafana-custom = {
  enable = true;
  port = 3100;
  bindIP = "0.0.0.0";
  dataDir = "/data/grafana";

  # Nginx reverse proxy
  domain = "grafana.example.com";
  enableSSL = true;

  # Security
  adminPassword = "YourSecurePassword";
  allowAnonymous = false;

  openFirewall = true;
};


================================================================================
INITIAL SETUP
================================================================================

1. First Login:
   - Navigate to http://your-server:3100 (or your domain)
   - Username: admin
   - Password: admin (or your configured adminPassword)
   - Change password immediately!

2. Add Data Sources:
   - Click "Configuration" (gear icon) → "Data sources"
   - Click "Add data source"
   - Popular options:
     * Prometheus (for metrics)
     * Loki (for logs)
     * InfluxDB (for time-series)
     * PostgreSQL/MySQL (for databases)

3. Import Dashboards:
   - Click "+" → "Import"
   - Use dashboard ID from https://grafana.com/grafana/dashboards/
   - Or upload JSON dashboard files


================================================================================
CONFIGURATION
================================================================================

Grafana configuration is controlled via:
1. Environment variables (set in systemd service)
2. grafana.ini file (in dataDir)

Edit configuration:
  sudo nano /var/lib/grafana/grafana.ini
  sudo systemctl restart grafana

Full configuration reference:
  https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/

Key settings:
  - [server] section: HTTP/HTTPS settings
  - [database] section: Database backend
  - [auth.*] sections: Authentication methods
  - [security] section: Security settings
  - [smtp] section: Email notifications


================================================================================
COMMON DATA SOURCES
================================================================================

Prometheus (metrics):
  Add this to your configuration:
  services.prometheus = {
    enable = true;
    port = 9090;
  };
  Then add http://localhost:9090 as Prometheus data source in Grafana

Loki (logs):
  services.loki = {
    enable = true;
  };
  Then add http://localhost:3100 as Loki data source in Grafana

InfluxDB (time-series):
  services.influxdb2.enable = true;
  Configure InfluxDB data source with your org/bucket/token


================================================================================
POPULAR DASHBOARD IDs
================================================================================

System Monitoring:
  - Node Exporter Full: 1860
  - Node Exporter for Prometheus: 11074

Docker:
  - Docker Container & Host Metrics: 10619
  - Docker and System Monitoring: 893

Network:
  - SNMP Stats: 11169
  - Network UPS Tools: 14371

Applications:
  - Nginx: 12708
  - PostgreSQL: 9628
  - MySQL: 7362

Import from: Dashboard ID → Load → Select Prometheus → Import


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status grafana

View logs:
  sudo journalctl -u grafana -f
  # Or check log files:
  sudo tail -f /var/lib/grafana/logs/grafana.log

Reset admin password:
  sudo -u grafana ${pkgs.grafana}/bin/grafana server admin reset-admin-password newpassword --homepath=${pkgs.grafana}/share/grafana

Install plugins:
  sudo -u grafana ${pkgs.grafana}/bin/grafana server plugins install <plugin-id> --homepath=${pkgs.grafana}/share/grafana
  sudo systemctl restart grafana

List installed plugins:
  sudo -u grafana ${pkgs.grafana}/bin/grafana server plugins ls --homepath=${pkgs.grafana}/share/grafana

Common issues:
  - Cannot connect to data source: Check firewall rules
  - Permission denied: Check file permissions in dataDir
  - Port already in use: Change cfg.port
  - Dashboard not loading: Check browser console for errors


================================================================================
SECURITY BEST PRACTICES
================================================================================

1. Change default admin password immediately
2. Use strong passwords for all users
3. Enable HTTPS (set enableSSL = true with domain)
4. Disable anonymous access unless needed
5. Use authentication providers (LDAP, OAuth, SAML)
6. Regularly update Grafana: Update pkgs.grafana
7. Review user permissions regularly
8. Enable audit logging for production


================================================================================
PLUGIN MANAGEMENT
================================================================================

Install plugins via CLI:
  sudo -u grafana ${pkgs.grafana}/bin/grafana server plugins install grafana-clock-panel --homepath=${pkgs.grafana}/share/grafana
  sudo systemctl restart grafana

Popular plugins:
  - grafana-clock-panel: Clock widget
  - grafana-piechart-panel: Pie charts
  - grafana-worldmap-panel: World map visualization
  - alexanderzobnin-zabbix-app: Zabbix integration

Browse plugins:
  https://grafana.com/grafana/plugins/

*/
