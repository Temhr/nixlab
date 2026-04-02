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
        # ── Left column ──────────
        size = "small";
        widgets = [
          {
            type = "monitor";
            cache = "1m";
            title = "Homepage";
            sites = [
              {
                title = "nixace services";
                url = "http://192.168.0.200:3000/";
                icon = "si:homepage";
              }
              {
                title = "nixsun services";
                url = "http://192.168.0.203:3000/";
                icon = "si:homepage";
              }
              {
                title = "nixtop services";
                url = "http://192.168.0.202:3000/";
                icon = "si:homepage";
              }
              {
                title = "nixvat services";
                url = "http://192.168.0.201:3000/";
                icon = "si:homepage";
              }
              {
                title = "nixzen services";
                url = "http://192.168.0.204:3000/";
                icon = "si:homepage";
              }
            ];
          }
        ];
      }
      {
        # ── Main column ──────────────
        size = "full";
        widgets = [
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
                url = "https://freebooters.uk/rss.xml";
                title = "Freebooters (podcast)";
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
                url = "https://brennan.day/feed.xml";
                title = "Brennan Day (blog)";
              }
              {
                url = "https://emilygorcenski.com/index.xml";
                title = "Emily Gorcenski (blog)";
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
      {
        # ── Right column ──────────
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
    ];
  }
]
