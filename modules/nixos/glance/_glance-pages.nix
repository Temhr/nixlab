# _glance-pages.nix
# Glance pages and widget configuration.
# Docs: https://github.com/glanceapp/glance/blob/main/docs/configuration.md
#
# This file returns a list of pages. Each page has a name and a list of
# columns. Each column has a size ("small" | "full" | "large") and a list
# of widgets. The structure maps 1-to-1 onto glance.yml — it is converted
# to YAML and appended to the server block by glance.nix.
[
  {
    # ──────────────────────────────────────────────
    # PAGE: Home
    # ──────────────────────────────────────────────
    name = "Home";
    columns = [
      {
        # ── Left column: clock + calendar ──────────
        size = "small";
        widgets = [
          {
            type = "clock";
            hour-format = "24h";
          }
          {
            type = "calendar";
          }
        ];
      }
      {
        # ── Main column: monitor + RSS ──────────────
        size = "full";
        widgets = [
          {
            type = "monitor";
            cache = "1m";
            title = "Services";
            sites = [
              {
                title = "Home Assistant";
                url = "http://192.168.0.200:8123";
                icon = "si:homeassistant";
              }
              {
                title = "Grafana - nixace";
                url = "http://192.168.0.200:3101";
                icon = "si:grafana";
              }
              {
                title = "Grafana - nixvat";
                url = "http://192.168.0.201:3101";
                icon = "si:grafana";
              }
              {
                title = "Prometheus - nixace";
                url = "http://192.168.0.200:9090";
                icon = "si:prometheus";
              }
              {
                title = "Syncthing - nixvat";
                url = "http://192.168.0.201:8384";
                icon = "si:syncthing";
              }
            ];
          }
          {
            type = "rss";
            limit = 50;
            "collapse-after" = 30;
            cache = "3h";
            feeds = [
              {
                url = "https://feather.onl/feeds";
                title = "Wing's stuff";
              }
              {
                url = "https://chriswere.wales/rss.xml";
                title = "Chris Were's stuff";
              }
              {
                url = "https://thepolarbear.co.uk";
                title = "Hamish's stuff";
              }
              {
                url = "https://friendo.monster/rss.xml";
                title = "Drew's blog";
              }
              {
                url = "https://subdermalcassetteloader.com/rss.xml";
                title = "Subdermal's blog";
              }
              {
                url = "https://blog.thefrenchghosty.me/index.xml";
                title = "The French Ghosty's blog";
              }
              {
                url = "https://brennan.day/feed.xml";
                title = "Brennan Day (blog)";
              }
              {
                url = "https://emilygorcenski.com/index.xml";
                title = "Emily Gorcenski (blog)";
              }
              {
                url = "https://freebooters.uk/rss.xml";
                title = "Freebooters (podcast)";
              }
              {
                url = "https://blog.ewancroft.uk/rss";
                title = "Ewan Croft (blog)";
              }
              {
                url = "https://mane.quest/index.xml";
                title = "The Lion's Den (blog)";
              }
              {
                url = "https://unmovedcentre.com/feed.xml";
                title = "Unmoved Centre (blog)";
              }
              {
                url = "https://xeiaso.net/blog.rss";
                title = "Xe's (blog)";
              }
            ];
          }
        ];
      }
    ];
  }
]
