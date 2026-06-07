{...}: {
  flake.nixosModules.servc--grafana-nixlab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.grafana-nixlab;

    # The module's own dashboards directory — all JSON files live here.
    # extraDashboards entries are resolved to paths inside this folder.
    dashboardsDir = ./dashboards;

    # Convert the extraDashboards list of names into the same attrset shape
    # as cfg.dashboards, resolving each name to its path in dashboardsDir.
    extraDashboardAttrs = lib.listToAttrs (map (name: {
        inherit name;
        value = {
          path = "${dashboardsDir}/${name}.json";
          folder = "maintenance";
          editable = true;
          updateInterval = 10;
        };
      })
      cfg.extraDashboards);

    # Single merged set used everywhere in config.
    allDashboards = cfg.dashboards // extraDashboardAttrs;

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
        };
        folder = lib.mkOption {
          type = lib.types.str;
          default = "maintenance";
          description = "Grafana folder to place this dashboard in.";
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

      # ── Base dashboards (module-owned, always provisioned) ──────────────────
      dashboards = lib.mkOption {
        type = lib.types.attrsOf dashboardSubmodule;
        description = ''
          Module-owned dashboards provisioned on every host that enables this
          service. To add host-specific dashboards without touching this set,
          use extraDashboards instead.
        '';
        default = {
          maintenance = {
            path = "${dashboardsDir}/maintenance-checklist.json";
            folder = "maintenance";
          };
          system-overview = {
            path = "${dashboardsDir}/system-overview-v3.json";
            folder = "maintenance";
          };
        };
      };

      # ── Per-host extras: just name the JSON file (no path needed) ──────────
      extraDashboards = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Names of additional dashboards to provision on this host.
          Each name must match a JSON file in the module's own dashboards/
          directory (e.g. "zfs-monitoring" loads dashboards/zfs-monitoring.json).

          All extra dashboards are placed in the "maintenance" folder and are
          editable by default.

          Example — enable the ZFS dashboard on a host that has ZFS:

            services.grafana-nixlab.extraDashboards = [ "zfs-monitoring" ];

          Example — enable multiple extra dashboards:

            services.grafana-nixlab.extraDashboards = [
              "zfs-monitoring"
              "docker"
              "nginx"
            ];
        '';
        example = ["zfs-monitoring" "docker"];
      };
    };

    # ============================================================================
    # CONFIG
    # ============================================================================
    config = lib.mkIf cfg.enable {
      # Guard: catch unknown dashboard names before anything tries to run.
      assertions = [
        {
          assertion =
            builtins.all (
              name:
                builtins.pathExists "${dashboardsDir}/${name}.json"
            )
            cfg.extraDashboards;
          message = let
            missing =
              builtins.filter (
                name:
                  !(builtins.pathExists "${dashboardsDir}/${name}.json")
              )
              cfg.extraDashboards;
          in ''
            services.grafana-nixlab.extraDashboards references JSON files that do
            not exist in the module's dashboards/ directory:
              ${lib.concatStringsSep "\n  " (map (n: "${n}.json") missing)}
            Add the missing files to modules/nixos/dashboards/ and run
            `git add` so the flake can see them.
          '';
        }
        {
          assertion = let
            baseKeys = builtins.attrNames cfg.dashboards;
            extraKeys = cfg.extraDashboards;
            dupes = builtins.filter (k: builtins.elem k baseKeys) extraKeys;
          in
            dupes == [];
          message = let
            baseKeys = builtins.attrNames cfg.dashboards;
            extraKeys = cfg.extraDashboards;
            dupes = builtins.filter (k: builtins.elem k baseKeys) extraKeys;
          in ''
            services.grafana-nixlab.extraDashboards names that clash with
            built-in dashboards: ${lib.concatStringsSep ", " dupes}.
            These are already provisioned by default; remove them from
            extraDashboards.
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

      # ── User / group ─────────────────────────────────────────────────────────
      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        description = "Grafana service user";
      };

      users.groups.${cfg.group} = {};

      users.users.${config.nixlab.mainUser}.extraGroups = lib.mkAfter [cfg.group];

      # ── Grafana systemd service ───────────────────────────────────────────────
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
              # Step 1 — runs as root (+):
              #   a) Remove any dashboard directories and provisioning configs
              #      that are no longer in allDashboards (stale cleanup).
              #   b) Create all directories the provisioning step needs.
              "+${pkgs.writeShellScript "grafana-setup" ''
                # ── known dashboard names (set at eval time) ──────────────────
                known="${lib.concatStringsSep " " (builtins.attrNames allDashboards)}"

                # ── clean up stale dashboard directories ──────────────────────
                if [ -d ${cfg.dataDir}/dashboards ]; then
                  for dir in ${cfg.dataDir}/dashboards/*/; do
                    [ -d "$dir" ] || continue
                    name="$(basename "$dir")"
                    found=0
                    for k in $known; do
                      [ "$k" = "$name" ] && found=1 && break
                    done
                    if [ "$found" = "0" ]; then
                      echo "grafana-setup: removing stale dashboard: $name"
                      rm -rf "$dir"
                    fi
                  done
                fi

                # ── clean up stale provisioning YAML configs ──────────────────
                if [ -d ${cfg.dataDir}/provisioning/dashboards ]; then
                  for yaml in ${cfg.dataDir}/provisioning/dashboards/*.yaml; do
                    [ -f "$yaml" ] || continue
                    name="$(basename "$yaml" .yaml)"
                    found=0
                    for k in $known; do
                      [ "$k" = "$name" ] && found=1 && break
                    done
                    if [ "$found" = "0" ]; then
                      echo "grafana-setup: removing stale provisioning config: $name.yaml"
                      rm -f "$yaml"
                    fi
                  done
                fi

                # ── create required directories ───────────────────────────────
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

              # Step 2 — runs as grafana user: copy JSON files and write
              # provisioning YAML configs for every dashboard in allDashboards.
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
                          deleteDashboardsOnResync: true
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

      # ── nginx reverse proxy ──────────────────────────────────────────────────
      services.nginx.enable = lib.mkIf (cfg.domain != null) true;

      services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
        ${cfg.domain} = {
          forceSSL = cfg.enableSSL;
          enableACME = cfg.enableSSL;

          locations."/" = {
            proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host               $host;
              proxy_set_header X-Real-IP          $remote_addr;
              proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto  $scheme;
              proxy_set_header Upgrade            $http_upgrade;
              proxy_set_header Connection         "upgrade";
              proxy_buffer_size       128k;
              proxy_buffers         4 256k;
              proxy_busy_buffers_size 256k;
            '';
          };
        };
      };

      # ── Firewall ─────────────────────────────────────────────────────────────
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
        lib.optionals (cfg.domain == null) [cfg.port]
        ++ lib.optionals (cfg.domain != null) [80 443]
      );
    };
  };
}
