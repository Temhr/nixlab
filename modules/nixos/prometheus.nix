{ config, lib, pkgs, ... }:

let
  cfg = config.services.prometheus-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.prometheus-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Prometheus monitoring system";

      # OPTIONAL: Port to listen on (default: 9090)
      port = lib.mkOption {
        type = lib.types.port;
        default = 9090;
        description = "Port for Prometheus to listen on";
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
        example = "prometheus.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      # Only works if domain is set
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      # OPTIONAL: Where to store Prometheus data (default: /var/lib/prometheus2)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/prometheus2";
        example = "/data/prometheus";
        description = "Directory for Prometheus time-series data";
      };

      # OPTIONAL: Data retention period (default: 15d)
      retention = lib.mkOption {
        type = lib.types.str;
        default = "15d";
        example = "30d";
        description = "How long to retain metrics data";
      };

      # OPTIONAL: Prometheus package to use (default: pkgs.prometheus)
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.prometheus;
        defaultText = lib.literalExpression "pkgs.prometheus";
        description = "The Prometheus package to use";
      };

      # OPTIONAL: Auto-open firewall ports (default: true)
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports";
      };

      # OPTIONAL: Enable node exporter for system metrics (default: true)
      enableNodeExporter = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Prometheus Node Exporter for system metrics";
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
      "d ${cfg.dataDir} 0770 prometheus prometheus -"
    ];

    # ----------------------------------------------------------------------------
    # USER SETUP - Create dedicated system user for Prometheus
    # ----------------------------------------------------------------------------
    users.users.prometheus = {
      isSystemUser = true;
      group = "prometheus";
      home = cfg.dataDir;
      description = "Prometheus service user";
    };

    users.groups.prometheus = {};

    users.users.temhr.extraGroups = [ "prometheus" ];

    # ----------------------------------------------------------------------------
    # PROMETHEUS SERVICE - Configure the systemd service
    # ----------------------------------------------------------------------------
    systemd.services.prometheus = {
      # Set a description that will appear in systemctl output
      # Change this if you want a different display name
      description = "Prometheus Monitoring System";

      # Control when this service starts during boot
      # Options: multi-user.target (normal), graphical.target (GUI systems)
      wantedBy = [ "multi-user.target" ];

      # Add dependencies here - services that must start before Prometheus
      # Example: after = [ "network.target" "postgresql.service" ];
      after = [ "network.target" ];

      serviceConfig = {
        # Service type determines how systemd manages the process
        # Use "simple" for processes that don't fork, "forking" if they daemonize
        Type = "simple";

        # Set which user/group runs Prometheus for security isolation
        # Change these if you need different permissions or user separation
        User = "prometheus";
        Group = "prometheus";

        # Main command - add or modify flags to customize Prometheus behavior
        # Common additions:
        # --web.external-url=https://your-domain.com/prometheus (for reverse proxy)
        # --log.level=debug (for more verbose logging)
        # --storage.tsdb.retention.size=10GB (limit storage by size instead of time)
        ExecStart = ''
          ${cfg.package}/bin/prometheus \
            --config.file=${cfg.dataDir}/prometheus.yml \
            --storage.tsdb.path=${cfg.dataDir}/data \
            --storage.tsdb.retention.time=${cfg.retention} \
            --web.listen-address=${cfg.bindIP}:${toString cfg.port} \
            --web.console.templates=${cfg.package}/etc/prometheus/consoles \
            --web.console.libraries=${cfg.package}/etc/prometheus/console_libraries
        '';

        # Define how to reload config without restarting (preserves metrics data)
        # HUP signal tells Prometheus to reload its configuration file
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";

        # Control restart behavior on failure
        # Options: "no", "on-success", "on-failure", "always"
        Restart = "on-failure";

        # Adjust delay before restart attempts (increase if startup is slow)
        RestartSec = "10s";

        # ---- Security hardening - uncomment/add options as needed ----

        # Prevent privilege escalation attacks
        NoNewPrivileges = true;

        # Isolate /tmp from other services (recommended for security)
        PrivateTmp = true;

        # Filesystem protection level: "strict" (read-only), "full", or "true"
        ProtectSystem = "strict";

        # Hide /home directories from this service
        ProtectHome = true;

        # List directories that need write access
        # Add more paths if Prometheus needs to write elsewhere:
        # ReadWritePaths = [ cfg.dataDir "/var/log/prometheus" ];
        ReadWritePaths = [ cfg.dataDir ];

        # Additional security options you can enable:
        # PrivateDevices = true;  # Restrict device access
        # ProtectKernelTunables = true;  # Protect /proc and /sys
        # RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];  # Limit network protocols
      };

      # ----------------------------------------------------------------------------
      # PRE-START SCRIPT - Runs before service starts each time
      # Use this to generate configs, check dependencies, or prepare directories
      # ----------------------------------------------------------------------------
      preStart = let
        # Define your Prometheus configuration here
        # This Nix structure gets converted to prometheus.yml automatically
        prometheusConfig = {
          # Global defaults - adjust timing based on your monitoring needs
          # Shorter intervals = more data points but higher resource usage
          global = {
            scrape_interval = "15s";       # Change to 30s or 60s for less frequent scraping
            evaluation_interval = "15s";   # How often to check alerting rules
            external_labels = { monitor = "prometheus"; };  # Add labels to identify this instance
          };

          # Configure alertmanager endpoints (add your alertmanager targets here)
          alerting = {
            alertmanagers = [{
              static_configs = [{
                targets = [];  # Example: [ "alertmanager:9093" ]
              }];
            }];
          };

          # Add paths to alerting rule files here
          # rule_files = [ "/etc/prometheus/alerts/*.yml" ];
          rule_files = [];

          # Define what to scrape - add new jobs here for each service you monitor
          scrape_configs =
            [
              # Self-monitoring job - always keep this to monitor Prometheus health
              {
                job_name = "prometheus";
                static_configs = [{
                  targets = [ "localhost:${toString cfg.port}" ];
                }];
              }
            ]
            # Example of conditional scrape config - add more with ++ operator
            ++ lib.optional cfg.enableNodeExporter {
              job_name = "node";
              static_configs = [{
                targets = [ "localhost:9100" ];
                labels = { instance = "localhost"; };
              }];
            }
            # Add your own scrape configs here:
            # ++ [{
            #   job_name = "my-app";
            #   static_configs = [{
            #     targets = [ "localhost:8080" ];
            #     labels = { environment = "production"; };
            #   }];
            # }]
            ;
        };

        # Converts Nix config to JSON as an intermediate format
        # Modify prometheusConfig above, not this line
        jsonFile = builtins.toFile "prometheus.json"
          (builtins.toJSON prometheusConfig);

        # Temporary file path for YAML conversion
        yamlTmp = "${cfg.dataDir}/prometheus.yml.tmp";
      in ''
# Convert JSON to YAML (Prometheus requires YAML format)
# If you need a custom config file instead, replace this entire script
${pkgs.remarshal}/bin/remarshal \
  -i ${jsonFile} \
  -o ${yamlTmp} \
  -if json \
  -of yaml

# Install config with specific permissions (660 = user and group read/write)
# Adjust -m flag if you need different permissions
install -m 660 -o prometheus -g prometheus ${yamlTmp} ${cfg.dataDir}/prometheus.yml

# Ensure data directory exists
# Add additional directories here if needed:
# mkdir -p ${cfg.dataDir}/wal ${cfg.dataDir}/rules
mkdir -p ${cfg.dataDir}/data

# Set ownership on directories
# Add chown commands for any additional directories you create
chown prometheus:prometheus ${cfg.dataDir}/data

# Additional preStart tasks you might add:
# - Validate config: ${cfg.package}/bin/promtool check config ${cfg.dataDir}/prometheus.yml
# - Download rule files from remote source
# - Set up symbolic links to rule files
# - Initialize databases or plugins
      '';
    };

    # ----------------------------------------------------------------------------
    # NODE EXPORTER - Enable if requested
    # ----------------------------------------------------------------------------
    systemd.services.prometheus-node-exporter = lib.mkIf cfg.enableNodeExporter {
      description = "Prometheus Node Exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "prometheus";
        Group = "prometheus";
        ExecStart = "${pkgs.prometheus-node-exporter}/bin/node_exporter --web.listen-address=localhost:9100";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

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
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Basic auth recommended for production
            # auth_basic "Prometheus";
            # auth_basic_user_file /etc/nginx/.htpasswd;
          '';
        };
      };
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      # Open Prometheus port if not using reverse proxy
      lib.optionals (cfg.domain == null) [ cfg.port ]
      # Open HTTP/HTTPS if using reverse proxy
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );
  };
}

/*
================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration:
----------------------
services.prometheus-custom = {
  enable = true;
};
# Access at: http://your-ip:9090
# Node Exporter enabled by default on localhost:9100


Full configuration with domain:
--------------------------------
services.prometheus-custom = {
  enable = true;
  port = 9090;
  bindIP = "0.0.0.0";
  dataDir = "/data/prometheus";
  retention = "30d";

  # Nginx reverse proxy
  domain = "prometheus.example.com";
  enableSSL = true;

  enableNodeExporter = true;
  openFirewall = true;
};


================================================================================
INITIAL SETUP
================================================================================

1. Access Prometheus:
   - Navigate to http://your-server:9090 (or your domain)
   - No authentication by default (add nginx auth for production)

2. Verify Targets:
   - Go to Status → Targets
   - Should see 'prometheus' and 'node' targets as UP

3. Query Metrics:
   - In the query box, try: node_cpu_seconds_total
   - Click "Execute" to see results
   - Switch to "Graph" tab for visualization

4. Add to Grafana:
   - In Grafana: Configuration → Data Sources → Add Prometheus
   - URL: http://localhost:9090 (or your Prometheus address)
   - Click "Save & Test"


================================================================================
CONFIGURATION
================================================================================

Prometheus configuration is generated automatically from Nix config.
The YAML file is regenerated on every service start.

View generated configuration:
  cat /var/lib/prometheus2/prometheus.yml

Configuration reference:
  https://prometheus.io/docs/prometheus/latest/configuration/configuration/

Note: Manual edits to prometheus.yml will be overwritten on restart.
To persist changes, modify the Nix module instead.


================================================================================
ADDING SCRAPE TARGETS
================================================================================

To add custom scrape targets, you'll need to modify the module's
scrape_configs section in the preStart script, or manually manage
prometheus.yml (noting it will be regenerated).

For production use, consider using the official NixOS prometheus module
which provides more configuration options:
  services.prometheus.enable = true;


================================================================================
COMMON EXPORTERS
================================================================================

Node Exporter (system metrics):
  Enabled by default with enableNodeExporter = true
  Metrics available at localhost:9100

Blackbox Exporter (probing):
  services.prometheus.exporters.blackbox.enable = true;
  # Probe HTTP endpoints, TCP ports, ICMP

Postgres Exporter:
  services.prometheus.exporters.postgres.enable = true;
  # Database metrics

Nginx Exporter:
  services.prometheus.exporters.nginx.enable = true;
  # Web server metrics

More exporters:
  https://prometheus.io/docs/instrumenting/exporters/


================================================================================
ALERTING
================================================================================

To add alerting rules, you'll need to modify the prometheusConfig
in the preStart section to include rule_files.

Example modification:
  rule_files = [ "${cfg.dataDir}/alerts.yml" ];

Then create alerts.yml manually:
  sudo nano /var/lib/prometheus2/alerts.yml

Example alerts.yml:
  groups:
    - name: system_alerts
      rules:
        - alert: HighCPU
          expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High CPU usage on {{ $labels.instance }}"
            description: "CPU usage is {{ $value }}%"


================================================================================
USEFUL QUERIES
================================================================================

CPU Usage:
  100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

Memory Usage:
  (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

Disk Usage:
  100 - ((node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100)

Network Received (bytes/sec):
  rate(node_network_receive_bytes_total[5m])

Load Average:
  node_load1

Uptime (seconds):
  node_time_seconds - node_boot_time_seconds


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status prometheus

View logs:
  sudo journalctl -u prometheus -f

Reload configuration:
  sudo systemctl restart prometheus

Check target connectivity:
  curl http://localhost:9100/metrics  # Node exporter

Query Prometheus API:
  curl 'http://localhost:9090/api/v1/query?query=up'

Common issues:
  - Target down: Check firewall, verify exporter is running
  - Config issues: Check logs for YAML parsing errors
  - High memory usage: Reduce retention time or scrape frequency
  - Disk full: Increase retention or add more storage


================================================================================
RETENTION AND STORAGE
================================================================================

Default retention: 15 days
Adjust with: retention = "30d";

Retention options:
  - Time-based: "15d", "30d", "1y"
  - Size-based: Add --storage.tsdb.retention.size to ExecStart

Estimate storage needs:
  ~1-2 bytes per sample
  samples_per_second = targets × metrics × scrape_frequency

Example:
  10 targets × 1000 metrics × (1 scrape / 15s) = 667 samples/s
  667 × 1.5 bytes × 86400 seconds/day = ~86 MB/day

Compact old data:
  Prometheus automatically compacts blocks
  Data in ${cfg.dataDir}/data


================================================================================
SECURITY BEST PRACTICES
================================================================================

1. Use nginx reverse proxy with authentication
2. Restrict access with firewall rules
3. Enable HTTPS (set enableSSL = true with domain)
4. Use read-only accounts for Grafana access
5. Regularly update Prometheus package
6. Monitor Prometheus resource usage
7. Set up alerting for Prometheus health
8. Backup prometheus configuration

*/
