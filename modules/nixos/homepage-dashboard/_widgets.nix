# /var/lib/homepage/config/widgets.yaml
# Homepage top-of-page widget bar configuration
# Docs: https://gethomepage.dev/en/configs/widgets/
{...}: [
  # ── System resources (cpu, memory, disk, network, uptime — all one block) ─
  # Homepage only supports a single `resources` entry in widgets.yaml.
  {
    resources = {
      label = "${config.networking.hostName} - system resources";
      cpu = true;
      memory = true;
      disk = "/";
      network = true;
      uptime = true;
      expanded = true;
      cacheInterval = 5000;
    };
  }

  # ── Search bar ────────────────────────────────────────────────────────────
  {
    search = {
      provider = "duckduckgo";
      target = "_blank";
    };
  }

  # ── Date & time ───────────────────────────────────────────────────────────
  {
    datetime = {
      text_size = "xl";
      locale = "en-CA";
      format = {
        timeStyle = "short";
        dateStyle = "short";
        hourCycle = "h23";
      };
    };
  }

  # ── Weather — Ottawa (open-meteo, no API key needed) ─────────────────────
  {
    openmeteo = {
      label = "Ottawa";
      latitude = 45.4247;
      longitude = -75.7045;
      units = "metric";
      cache = 15;
    };
  }

  # ── Grafana active alerts ─────────────────────────────────────────────────
  # Uncomment once you've confirmed Homepage can reach Grafana.
  # {
  #   grafana = {
  #     url = "http://${hostMeta.address}:3101";
  #     username = "admin";
  #     password = "{{HOMEPAGE_VAR_GRAFANA_PASSWORD}}";
  #   };
  # }
]
