{...}: {
  flake.nixosModules.servc--grafana-nixlab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.grafana-nixlab;

    # Single merged set used everywhere in config.
    # extraDashboards keys must not clash with dashboards keys — validated below.
    allDashboards = cfg.dashboards // cfg.extraDashboards;

    rootUrl =
      if cfg.domain != null
      then "${
        if cfg.enableSSL
        then "https"
        else "http"
      }://${cfg.domain}/"
      else "http://localhost:${toString cfg.port}/";

    serverDomain =
      if cfg.domain != null
      then cfg.domain
      else "localhost";

    # Reusable submodule type for a single dashboard entry.
    dashboardSubmodule = lib.types.submodule {
      options = {
        path = lib.mkOption {
          type = lib.types.path;
          description = "Path to the dashboard JSON file.";
          example = lib.literalExpression "./my-dashboard.json";
        };

        folder = lib.mkOption {
          type = lib.types.str;
          default = "General";
          description = "Grafana folder to place this dashboard in.";
          example = "System Monitoring";
        };

        editable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Allow editing this dashboard in the Grafana UI.";
        };

        updateInterval = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "How often Grafana checks for file changes (seconds).";
        };
      };
    };
  in {
    # ============================================================================
    # OPTIONS
    # ============================================================================
    options.services.grafana-nixlab = {
      enable = lib.mkEnableOption "Grafana monitoring and visualization platform";

      port = lib.mkOption {
        type = lib.types.port;
        default = 3101;
        description = "Port for Grafana to listen on.";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address to bind to. Use 0.0.0.0 for all interfaces.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "grafana.example.com";
        description = "Domain name for nginx reverse proxy. Null disables the proxy.";
      };

      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt. Requires domain to be set.";
      };

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/grafana";
        example = "/data/grafana";
        description = "Root directory for Grafana data, logs, plugins, and dashboards.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.grafana;
        defaultText = lib.literalExpression "pkgs.grafana";
        description = "The Grafana package to use.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports automatically.";
      };

      allowAnonymous = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow anonymous read-only access to dashboards.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "grafana";
        description = "System user to run Grafana as.";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "grafana";
        description = "System group to run Grafana as.";
      };

      credentialsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Path to a file containing the raw admin password (no KEY=VALUE wrapper).
          The service reads it at start time and writes a temporary credentials env
          file owned by the grafana user. If null, Grafana uses its built-in default.
        '';
      };

      # ── Base dashboards (module-owned) ──────────────────────────────────────
      dashboards = lib.mkOption {
        type = lib.types.attrsOf dashboardSubmodule;
        description = ''
          Module-owned dashboards provisioned on every host that enables this
          service. Override the whole set only if you want to remove built-in
          dashboards; to add host-specific dashboards use extraDashboards instead.
        '';
        default = {
          maintenance = {
            path = ./dashboards/maintenance-checklist.json;
            folder = "maintenance";
            editable = true;
          };
          system-overview = {
            path = ./dashboards/system-overview-v3.json;
            folder = "maintenance";
            editable = true;
          };
        };
        example = lib.literalExpression ''
          {
            my-app = {
              path = ./dashboards/my-app.json;
              folder = "Applications";
              editable = false;
            };
          }
        '';
      };

      # ── Per-host / per-stack extras ─────────────────────────────────────────
      extraDashboards = lib.mkOption {
        type = lib.types.attrsOf dashboardSubmodule;
        default = {};
        description = ''
          Additional dashboards merged on top of `dashboards`. Use this from
          monitoring.nix, global.nix, or individual host files to add dashboards
          without replacing the module defaults.

          Keys must not clash with those already defined in `dashboards`; a
          duplicate key causes an assertion failure at eval time.

          Example — adding a ZFS dashboard only on hosts that have ZFS:

            services.grafana-nixlab.extraDashboards.zfs-monitoring = {
              path = ./dashboards/zfs-monitoring.json;
              folder = "maintenance";
              editable = true;
            };
        '';
        example = lib.literalExpression ''
          {
            zfs-monitoring = {
              path = ./dashboards/zfs-monitoring.json;
              folder = "maintenance";
              editable = true;
            };
            docker = {
              path = ./dashboards/docker.json;
              folder = "Containers";
              editable = false;
            };
          }
        '';
      };
    };

    # ============================================================================
    # CONFIG
    # ============================================================================
    config = lib.mkIf cfg.enable {
      # Guard: catch key collisions between dashboards and extraDashboards early.
      assertions = [
        {
          assertion = let
            baseKeys = builtins.attrNames cfg.dashboards;
            extraKeys = builtins.attrNames cfg.extraDashboards;
            dupes = builtins.filter (k: builtins.elem k baseKeys) extraKeys;
          in
            dupes == [];
          message = let
            baseKeys = builtins.attrNames cfg.dashboards;
            extraKeys = builtins.attrNames cfg.extraDashboards;
            dupes = builtins.filter (k: builtins.elem k baseKeys) extraKeys;
          in ''
            services.grafana-nixlab.extraDashboards contains keys that clash with
            services.grafana-nixlab.dashboards: ${lib.concatStringsSep ", " dupes}.
            Rename the extraDashboards entries to avoid the collision.
          '';
        }
      ];

      # ── Directory setup ──────────────────────────────────────────────────────
      systemd.tmpfiles.rules =
        [
          "d ${cfg.dataDir}            0770 ${cfg.user} ${cfg.group} -"
          "d ${cfg.dataDir}/data       0770 ${cfg.user} ${cfg.group} -"
          "d ${cfg.dataDir}/logs       0770 ${cfg.user} ${cfg.group} -"
          "d ${cfg.dataDir}/plugins    0770 ${cfg.user} ${cfg.group} -"
          "d ${cfg.dataDir}/dashboards 0775 ${cfg.user} ${cfg.group} -"
        ]
        ++ lib.mapAttrsToList (
          name: _: "d ${cfg.dataDir}/dashboards/${name} 0775 ${cfg.user} ${cfg.group} -"
        )
        allDashboards;

      # ----------------------------------------------------------------------------
      # USER SETUP - Create dedicated system user for Grafana
      # ----------------------------------------------------------------------------
      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        description = "Grafana service user";
      };

      users.groups.${cfg.group} = {};

      users.users.${config.nixlab.mainUser}.extraGroups = lib.mkAfter [cfg.group];

      # ----------------------------------------------------------------------------
      # GRAFANA SERVICE - Configure the systemd service
      # ----------------------------------------------------------------------------
      systemd.services.grafana = {
        description = "Grafana Monitoring and Visualization Platform";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];

        environment = {
          GF_PATHS_DATA = "${cfg.dataDir}/data";
          GF_PATHS_LOGS = "${cfg.dataDir}/logs";
          GF_PATHS_PLUGINS = "${cfg.dataDir}/plugins";
          GF_PATHS_PROVISIONING = "${cfg.dataDir}/provisioning";
          GF_LOG_MODE = "console file";
          GF_LOG_LEVEL = "info";
          GF_SERVER_HTTP_PORT = toString cfg.port;
          GF_SERVER_HTTP_ADDR = cfg.listenAddress;
          GF_SERVER_DOMAIN = serverDomain;
          GF_SERVER_ROOT_URL = rootUrl;
          GF_AUTH_ANONYMOUS_ENABLED = lib.boolToString cfg.allowAnonymous;
          GF_AUTH_ANONYMOUS_ORG_ROLE = "Viewer";
          GF_DATABASE_TYPE = "sqlite3";
          GF_DATABASE_PATH = "${cfg.dataDir}/data/grafana.db";
        };

        serviceConfig =
          {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = cfg.dataDir;
            ExecStart = "${cfg.package}/bin/grafana server --homepath=${cfg.package}/share/grafana";
            Restart = "on-failure";
            RestartSec = "10s";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [cfg.dataDir];

            ExecStartPre = [
              # Step 1 — runs as root (+): create every directory that must exist
              # before the unprivileged provisioning step runs.
              "+${pkgs.writeShellScript "grafana-mkdir" ''
                install -d -m 0775 -o ${cfg.user} -g ${cfg.group} \
                  ${cfg.dataDir}/provisioning \
                  ${cfg.dataDir}/provisioning/dashboards \
                  ${cfg.dataDir}/provisioning/datasources \
                  ${cfg.dataDir}/provisioning/notifiers \
                  ${lib.concatStringsSep " \\\n                  " (
                  lib.mapAttrsToList (
                    name: _: "${cfg.dataDir}/dashboards/${name}"
                  )
                  allDashboards
                )}
              ''}"

              # Step 2 — runs as the grafana user: write credentials env file,
              # copy dashboard JSON files, and write provisioning YAML configs.
              (pkgs.writeShellScript "grafana-provision" (
                lib.optionalString (cfg.credentialsFile != null) ''
                  echo "GRAFANA_ADMIN_PASSWORD=$(cat ${cfg.credentialsFile})" \
                    > /run/grafana-credentials.env
                  chmod 600 /run/grafana-credentials.env
                ''
                + lib.concatStringsSep "\n" (lib.mapAttrsToList (name: dashboard: ''
                    # ── dashboard: ${name} ──
                    if [ -f ${dashboard.path} ]; then
                      install -m 644 ${dashboard.path} \
                        ${cfg.dataDir}/dashboards/${name}/dashboard.json
                    else
                      echo "WARNING: dashboard file not found: ${dashboard.path}" >&2
                    fi

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
                  '')
                  allDashboards)
              ))
            ];
          }
          // lib.optionalAttrs (cfg.credentialsFile != null) {
            EnvironmentFile = "/run/grafana-credentials.env";
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
            proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host              $host;
              proxy_set_header X-Real-IP         $remote_addr;
              proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header Upgrade           $http_upgrade;
              proxy_set_header Connection        "upgrade";
              proxy_buffer_size      128k;
              proxy_buffers        4 256k;
              proxy_busy_buffers_size 256k;
            '';
          };
        };
      };

      # ----------------------------------------------------------------------------
      # FIREWALL - Open necessary ports if requested
      # ----------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
        lib.optionals (cfg.domain == null) [cfg.port]
        ++ lib.optionals (cfg.domain != null) [80 443]
      );
    };
  };
}
/*
================================================================================
MULTIPLE DASHBOARDS USAGE
================================================================================

Basic example with multiple dashboards:
---------------------------------------
services.grafana-nixlab = {
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
services.grafana-nixlab = {
  enable = true;
  port = 3100;
  listenAddress = "0.0.0.0";
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
services.grafana-nixlab = {
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

