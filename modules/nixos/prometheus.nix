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
      description = "Prometheus Monitoring System";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "prometheus";
        Group = "prometheus";
        ExecStart = ''
          ${cfg.package}/bin/prometheus \
            --config.file=${cfg.dataDir}/prometheus.yml \
            --storage.tsdb.path=${cfg.dataDir}/data \
            --storage.tsdb.retention.time=${cfg.retention} \
            --web.listen-address=${cfg.bindIP}:${toString cfg.port} \
            --web.console.templates=${cfg.package}/etc/prometheus/consoles \
            --web.console.libraries=${cfg.package}/etc/prometheus/console_libraries
        '';
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };

      # Ensure config file exists with proper permissions
      preStart = let
        prometheusConfig = {
          global = {
            scrape_interval = "15s";
            evaluation_interval = "15s";
            external_labels = { monitor = "prometheus"; };
          };

          alerting = {
            alertmanagers = [{
              static_configs = [{
                targets = [];
              }];
            }];
          };

          rule_files = [];

          scrape_configs =
            [
              {
                job_name = "prometheus";
                static_configs = [{
                  targets = [ "localhost:${toString cfg.port}" ];
                }];
              }
            ]
            ++ lib.optional cfg.enableNodeExporter {
              job_name = "node";
              static_configs = [{
                targets = [ "localhost:9100" ];
                labels = { instance = "localhost"; };
              }];
            };
        };

        # Convert Nix → JSON → YAML manually
        prometheusJSON = builtins.toJSON prometheusConfig;
        prometheusYAML = pkgs.remarshal.toYAML prometheusJSON;
        prometheusFile = builtins.toFile "prometheus.yml" prometheusYAML;

      in
      ''
        install -m 660 -o prometheus -g prometheus ${prometheusFile} ${cfg.dataDir}/prometheus.yml

        mkdir -p ${cfg.dataDir}/data
        chown prometheus:prometheus ${cfg.dataDir}/data
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

Prometheus configuration is in prometheus.yml in dataDir.
A default config is created automatically on first run.

Edit configuration:
  sudo nano /var/lib/prometheus2/prometheus.yml
  sudo systemctl reload prometheus  # Reload without restart

Validate configuration:
  ${pkgs.prometheus}/bin/promtool check config /var/lib/prometheus2/prometheus.yml

Configuration reference:
  https://prometheus.io/docs/prometheus/latest/configuration/configuration/


================================================================================
ADDING SCRAPE TARGETS
================================================================================

Edit prometheus.yml and add scrape targets:

Example - Monitor a web application:
  - job_name: 'my-app'
    static_configs:
      - targets: ['localhost:8080']
        labels:
          service: 'webapp'
          environment: 'production'

Example - Monitor multiple hosts:
  - job_name: 'servers'
    static_configs:
      - targets:
          - 'server1.example.com:9100'
          - 'server2.example.com:9100'
        labels:
          datacenter: 'dc1'

Then reload:
  sudo systemctl reload prometheus


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

Create alert rules file:
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

        - alert: DiskSpaceLow
          expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Low disk space on {{ $labels.instance }}"

Update prometheus.yml to include:
  rule_files:
    - "alerts.yml"

Reload:
  sudo systemctl reload prometheus

Check alerts at: http://your-ip:9090/alerts


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
  sudo systemctl reload prometheus

Validate config syntax:
  ${pkgs.prometheus}/bin/promtool check config /var/lib/prometheus2/prometheus.yml

Check target connectivity:
  curl http://localhost:9100/metrics  # Node exporter

Query Prometheus API:
  curl 'http://localhost:9090/api/v1/query?query=up'

Common issues:
  - Target down: Check firewall, verify exporter is running
  - Config reload fails: Validate YAML syntax
  - High memory usage: Reduce retention time or scrape frequency
  - Disk full: Increase retention or add more storage


================================================================================
RETENTION AND STORAGE
================================================================================

Default retention: 15 days
Adjust with: retention = "30d";

Retention options:
  - Time-based: "15d", "30d", "1y"
  - Size-based: Set in ExecStart with --storage.tsdb.retention.size

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
8. Backup prometheus.yml and alert rules

*/
