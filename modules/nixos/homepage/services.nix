    {
      "Incus Server" = [
        {
          "Home Assistant" = {
            href = "http://192.168.0.200:8123";
            icon = "home-assistant";
            description = "Central home automation hub";
            target = "_blank";
            server = "nixace - Incus - HomeAssistant";
            ping = "http://192.168.0.200:8123";
            statusStyle = "dot";
          };
        }
        {
          "Node-RED" = {
            href = "http://192.168.0.200:1880";
            icon = "nodered";
            description = "Visual automation and flow-based logic editor";
            target = "_blank";
            server = "nixace - Incus - HomeAssistant";
            ping = "http://192.168.0.200:1880";
            statusStyle = "dot";
          };
        }
        {
          "BookStack" = {
            href = "http://192.168.0.200:2665/";
            icon = "bookstack";
            description = "Self-hosted documentation and notes";
            target = "_blank";
            server = "nixace - Incus - HomeAssistant";
            ping = "http://192.168.0.200:2665/";
            statusStyle = "dot";
          };
        }
      ];
    }

    {
      "Knowledge Base" = [
        {
          "Wiki.js" = {
            href = "http://192.168.0.201:3001";
            icon = "wikijs";
            description = "Structured and collaborative wiki platform";
            target = "_blank";
            server = "nixvat";
            ping = "http://192.168.0.201:3001";
            statusStyle = "dot";
          };
        }
      ];
    }

    {
      "Sync and Storage" = [
        {
          "Syncthing nixvat" = {
            href = "http://192.168.0.201:8384";
            icon = "syncthing";
            description = "Main sync node - Peer-to-peer file synchronization";
            target = "_blank";
            server = "nixvat";
            ping = "http://192.168.0.201:8384";
            statusStyle = "dot";
          };
        }
        {
          "Syncthing nixzen" = {
            href = "http://192.168.0.204:8384";
            icon = "syncthing";
            description = "Secondary sync node - Peer-to-peer file synchronization";
            target = "_blank";
            server = "nixzen";
            ping = "http://192.168.0.204:8384";
            statusStyle = "dot";
          };
        }
      ];
    }

    {
      "System & Web Services" = [
        {
          "Glance" = {
            href = "http://192.168.0.201:3004";
            icon = "gauge";
            description = "Lightweight system overview dashboard";
            target = "_blank";
            server = "nixvat";
            ping = "http://192.168.0.201:3004";
            statusStyle = "dot";
          };
        }
        {
          "Zola" = {
            href = "http://192.168.0.201:3003";
            icon = "zola";
            description = "Static site generator for personal or project pages";
            target = "_blank";
            server = "nixvat";
            ping = "http://192.168.0.201:3003";
            statusStyle = "dot";
          };
        }
      ];
    }

    {
      "Monitoring & Logs" = [
        {
          "Grafana" = {
            href = "http://192.168.0.201:3101";
            icon = "grafana";
            description = "Metrics visualization and dashboards";
            target = "_blank";
            server = "nixvat";
            ping = "http://192.168.0.201:3101";
            statusStyle = "dot";
          };
        }
        {
          "Prometheus" = {
            href = "http://192.168.0.201:9090";
            icon = "prometheus";
            description = "Metrics collection and monitoring";
            target = "_blank";
            widget = {
              type = "prometheus";
              url = "http://192.168.0.201:9090";
            };
            server = "nixvat";
            ping = "http://192.168.0.201:9090";
            statusStyle = "dot";
          };
        }
      ];
    }
