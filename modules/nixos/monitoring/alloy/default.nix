{...}: {
  flake.nixosModules.servc--alloy-nixlab = {
    config,
    lib,
    pkgs,
    nixlabLib,
    ...
  }: let
    cfg = config.services.alloy-nixlab;

    baseAlloyConfig = ''
      // Loki client for sending logs
      loki.write "local" {
        endpoint {
          url = "${cfg.lokiUrl}"
        }
      }

      // Collect systemd journal logs
      // journald exposes metadata as internal __journal_* labels. They are dropped
      // unless relabelled to a name without the "__" prefix.
      loki.relabel "journal" {
        forward_to = []

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }
        rule {
          source_labels = ["__journal_priority_keyword"]
          target_label  = "level"
        }
        rule {
          source_labels = ["__journal__transport"]
          target_label  = "transport"
        }
      }

      loki.source.journal "systemd" {
        max_age       = "12h"
        relabel_rules = loki.relabel.journal.rules
        labels = {
          job  = "systemd-journal",
          host = "${config.networking.hostName}",
        }

        forward_to = [loki.process.systemd.receiver]
      }

      loki.process "systemd" {
        forward_to = [loki.write.local.receiver]

        stage.static_labels {
          values = {
            job  = "systemd-journal",
            host = "${config.networking.hostName}",
          }
        }

        stage.label_keep {
          values = ["job", "host", "unit", "level", "transport"]
        }
      }

      // Collect system log files
      local.file_match "varlogs" {
        path_targets = [{
          __address__ = "localhost",
          __path__    = "/var/log/*.log",
        }]
      }

      loki.source.file "varlogs" {
        targets    = local.file_match.varlogs.targets
        forward_to = [loki.process.varlogs.receiver]
      }

      loki.process "varlogs" {
        forward_to = [loki.write.local.receiver]

        stage.static_labels {
          values = {
            job  = "varlogs",
            host = "${config.networking.hostName}",
          }
        }
      }
    '';

    alloyConfig = baseAlloyConfig + cfg.extraConfig;
    configFile = pkgs.writeText "alloy-config.alloy" alloyConfig;
  in {
    options.services.alloy-nixlab = {
      enable = lib.mkEnableOption "Grafana Alloy log collector";

      port = lib.mkOption {
        type = lib.types.port;
        default = 12345;
        description = "Port of Alloy's HTTP server (UI, /metrics). Bound to loopback.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.grafana-alloy;
        defaultText = lib.literalExpression "pkgs.grafana-alloy";
        description = "The Grafana Alloy package to use.";
      };

      lokiUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:3100/loki/api/v1/push";
        description = "Loki push endpoint. On an agent this points at the hub.";
      };

      afterLocalLoki = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Order Alloy after the local loki.service. Agents (no local Loki) set this to false.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "River configuration appended to the base pipelines (journal and /var/log/*.log).";
      };

      uid = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Pinned uid for the alloy user.";
      };

      gid = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Pinned gid for the alloy group.";
      };

      extraUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["alice"];
        description = "Extra users to add to the alloy group (the main user is added automatically).";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = [
        "d /var/lib/alloy 0750 alloy alloy -"
        "d /var/lib/alloy/data 0750 alloy alloy -"
      ];

      users.users = lib.mkMerge (
        [
          {
            alloy = {
              isSystemUser = true;
              group = "alloy";
              description = "Grafana Alloy service user";
              uid = cfg.uid;
              extraGroups = ["systemd-journal"];
            };
          }
        ]
        ++ lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
        (map (u: {${u} = {extraGroups = ["alloy"];};})
          ([config.nixlab.mainUser] ++ cfg.extraUsers))
      );

      users.groups.alloy = {gid = cfg.gid;};

      systemd.services.alloy-permissions = nixlabLib.mkDataDirPermissionsService {
        inherit pkgs;
        dataDir = "/var/lib/alloy";
        user = "alloy";
        group = "alloy";
        requiredBy = ["alloy.service"];
      };

      systemd.services.alloy = {
        description = "Grafana Alloy Telemetry Collector";
        wantedBy = ["multi-user.target"];
        after = ["network.target"] ++ lib.optional cfg.afterLocalLoki "loki.service" ++ ["alloy-permissions.service" "time-sync.target"];
        wants = ["time-sync.target"];

        serviceConfig =
          nixlabLib.mkServiceHardening {
            writablePaths = ["/var/lib/alloy"];
            allowJIT = true;
            extraHardening = true;
          }
          // {
            Type = "simple";
            User = "alloy";
            Group = "alloy";
            # Alloy reads process and journal metadata; keep /proc fully visible.
            ProtectProc = "default";
            ProcSubset = "all";
            ExecStart = "${cfg.package}/bin/alloy run --disable-reporting --server.http.listen-addr=127.0.0.1:${toString cfg.port} --storage.path=/var/lib/alloy/data /var/lib/alloy/config.alloy";
            Restart = "on-failure";
            RestartSec = "10s";
          };

        preStart = ''
          # Copy Alloy configuration
          install -m 640 -o alloy -g alloy ${configFile} /var/lib/alloy/config.alloy

          # Ensure data directory exists
          mkdir -p /var/lib/alloy/data
          chown -R alloy:alloy /var/lib/alloy
        '';
      };
    };
  };
}
