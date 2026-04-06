# /var/lib/homepage/config/services.yaml
# Homepage dashboard configuration
# Docs: https://gethomepage.dev/en/configs/services/
#
# To add a service to a machine, add its key to that host's
# hostMeta.services list. e.g.:
#
#   hostMeta.services = [ "ollama-gpu" "grafana" "syncthing-nixvat" ];
#
{
  allHosts,
  hostMeta,
}: let
  # ──────────────────────────────────────────────────────────────────────────
  # MASTER SERVICE DEFINITIONS
  # Add new services here. The attribute name is the key used in
  # hostMeta.services. Each entry is a Homepage service attrset.
  # ──────────────────────────────────────────────────────────────────────────
  allServices = {
    # ── AI & Inference ───────────────────────────────────────────────────────
    "ollama-cpu" = {
      "Ollama - CPU" = {
        href = "http://${hostMeta.address}:3007";
        icon = "ollama";
        description = "Local model inference — CPU backend";
        ping = "http://${hostMeta.address}:3007";
        statusStyle = "dot";
      };
    };

    "ollama-gpu" = {
      "Ollama - GPU" = {
        href = "http://${hostMeta.address}:3007";
        icon = "ollama";
        description = "Local model inference — GPU accelerated";
        ping = "http://${hostMeta.address}:3007";
        statusStyle = "dot";
      };
    };

    "comfyui" = {
      "ComfyUI" = {
        href = "http://${hostMeta.address}:8188";
        icon = "comfyui";
        description = "Stable Diffusion node-based pipeline";
        ping = "http://${hostMeta.address}:8188";
        statusStyle = "dot";
      };
    };

    # ── Knowledge & Docs ─────────────────────────────────────────────────────
    "bookstack" = {
      "BookStack" = {
        href = "http://${hostMeta.address}:6875/";
        icon = "bookstack";
        description = "Organised book/chapter/page wiki";
        ping = "http://${hostMeta.address}:6875/";
        statusStyle = "dot";
      };
    };

    "wikijs" = {
      "Wiki.js" = {
        href = "http://${hostMeta.address}:3001";
        icon = "wikijs";
        description = "Markdown-first wiki with git backend";
        ping = "http://${hostMeta.address}:3001";
        statusStyle = "dot";
      };
    };

    "zola" = {
      "Zola" = {
        href = "http://${hostMeta.address}:3003";
        icon = "zola";
        description = "Static site generator for personal or project pages";
        ping = "http://${hostMeta.address}:3003";
        statusStyle = "dot";
      };
    };

    # ── Monitoring & Logs ────────────────────────────────────────────────────
    "grafana" = {
      "Grafana" = {
        href = "http://${hostMeta.address}:3101";
        icon = "grafana";
        description = "Metrics visualisation and dashboards";
        ping = "http://${hostMeta.address}:3101";
        statusStyle = "dot";
      };
    };

    "prometheus" = {
      "Prometheus" = {
        href = "http://${hostMeta.address}:9090";
        icon = "prometheus";
        description = "Metrics scraping and alerting rules";
        ping = "http://${hostMeta.address}:9090";
        statusStyle = "dot";
      };
    };

    "loki" = {
      "Loki" = {
        icon = "loki";
        description = "Log aggregation and querying";
        ping = "http://${hostMeta.address}:3100";
        statusStyle = "dot";
      };
    };

    # ── Home & Automation ────────────────────────────────────────────────────
    "home-assistant" = {
      "Home Assistant" = {
        href = "http://${hostMeta.address}:8123";
        icon = "home-assistant";
        description = "Central home automation hub";
        ping = "http://${hostMeta.address}:8123";
        statusStyle = "dot";
      };
    };

    "node-red" = {
      "Node-RED" = {
        href = "http://${hostMeta.address}:1880";
        icon = "nodered";
        description = "Visual automation and flow-based logic editor";
        ping = "http://${hostMeta.address}:1880";
        statusStyle = "dot";
      };
    };

    # ── Sync and Storage ─────────────────────────────────────────────────────
    "syncthing-nixvat" = {
      "Syncthing nixvat" = {
        href = "http://${hostMeta.address}:8384";
        icon = "syncthing";
        description = "Main sync node — peer-to-peer file synchronisation";
        ping = "http://${hostMeta.address}:8384";
        statusStyle = "dot";
      };
    };

    "syncthing-nixzen" = {
      "Syncthing nixzen" = {
        href = "http://${hostMeta.address}:8384";
        icon = "syncthing";
        description = "Secondary sync node — peer-to-peer file synchronisation";
        ping = "http://${hostMeta.address}:8384";
        statusStyle = "dot";
      };
    };

    # ── Social & Feeds ───────────────────────────────────────────────────────
    "gotosocial" = {
      "GoToSocial" = {
        href = "http://${hostMeta.address}:8080";
        icon = "gotosocial";
        description = "Lightweight ActivityPub social server";
        ping = "http://${hostMeta.address}:8080";
        statusStyle = "dot";
      };
    };

    "glance" = {
      "Glance" = {
        href = "http://${allHosts.nixvat.address}:3004";
        icon = "gauge";
        description = "Feed dashboard — RSS, weather, links";
        ping = "http://${allHosts.nixvat.address}:3004";
        statusStyle = "dot";
      };
    };
  };

  # ──────────────────────────────────────────────────────────────────────────
  # SECTION GROUPING
  # Maps each service key to its display group. Add a new key here whenever
  # you add a new service above.
  # ──────────────────────────────────────────────────────────────────────────
  serviceGroups = {
    "ollama-cpu" = "AI & Inference";
    "ollama-gpu" = "AI & Inference";
    "comfyui" = "AI & Inference";
    "bookstack" = "Knowledge & Docs";
    "wikijs" = "Knowledge & Docs";
    "zola" = "Knowledge & Docs";
    "grafana" = "Monitoring & Logs";
    "prometheus" = "Monitoring & Logs";
    "loki" = "Monitoring & Logs";
    "home-assistant" = "Home & Automation";
    "node-red" = "Home & Automation";
    "syncthing-nixvat" = "Sync and Storage";
    "syncthing-nixzen" = "Sync and Storage";
    "gotosocial" = "Social & Feeds";
    "glance" = "Social & Feeds";
  };

  # ──────────────────────────────────────────────────────────────────────────
  # FILTER & GROUP — no edits needed below this line
  # ──────────────────────────────────────────────────────────────────────────

  # The groups that are actually present on this host (preserves order)
  groupOrder = [
    "AI & Inference"
    "Knowledge & Docs"
    "Monitoring & Logs"
    "Home & Automation"
    "Sync and Storage"
    "Social & Feeds"
  ];

  # Services active on this host
  activeServices =
    builtins.filter
    (key: builtins.elem key hostMeta.services)
    (builtins.attrNames allServices);

  # Build a { groupName = [ serviceAttrs... ] } map
  grouped =
    builtins.foldl'
    (
      acc: key: let
        group = serviceGroups.${key};
      in
        acc // {${group} = (acc.${group} or []) ++ [allServices.${key}];}
    )
    {}
    activeServices;

  # Emit only groups that have at least one active service, in defined order
  activeGroups = builtins.filter (g: grouped ? ${g}) groupOrder;
in
  map (group: {${group} = grouped.${group};}) activeGroups
