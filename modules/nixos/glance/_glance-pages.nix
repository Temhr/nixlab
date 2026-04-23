# _glance-pages.nix
# Glance pages and widget configuration.
# Docs: https://github.com/glanceapp/glance/blob/main/docs/configuration.md
#
# This file returns a list of pages. Each page has a name and a list of
# columns. Each column has a size ("small" | "full" | "large") and a list
# of widgets. The structure maps 1-to-1 onto glance.yml — it is converted
# to YAML and appended to the server block by glance.nix.
{allHosts}: [
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
                title = "${allHosts.nixace} services";
                url = "http://${allHosts.nixace.address}:3000/";
                icon = "si:homepage";
              }
              {
                title = "nixnas1 services";
                url = "http://${allHosts.nixnas1.address}:3000/";
                icon = "si:homepage";
              }
              {
                title = "nixsun services";
                url = "http://${allHosts.nixsun.address}:3000/";
                icon = "si:homepage";
              }
              {
                title = "nixtop services";
                url = "http://${allHosts.nixtop.address}:3000/";
                icon = "si:homepage";
              }
              {
                title = "nixvat services";
                url = "http://${allHosts.nixvat.address}:3000/";
                icon = "si:homepage";
              }
              {
                title = "nixzen services";
                url = "http://${allHosts.nixzen.address}:3000/";
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
            "collapse-after" = 4;
            cache = "3h";
            feeds = [
              {
                url = "https://feather.onl/feeds/all";
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
            ];
          }
          {
            type = "rss";
            limit = 50;
            "collapse-after" = 4;
            cache = "3h";
            feeds = [
              {
                url = "https://frontrowcrew.com/geeknights/podcast-rss/";
                title = "GeekNights (podcast)";
              }
              {
                url = "https://freebooters.uk/rss.xml";
                title = "Freebooters (podcast)";
              }
              {
                url = "https://video.thepolarbear.co.uk/feeds/videos.xml?videoChannelId=5005";
                title = "Freebooters (Peertube)";
              }
              {
                url = "https://video.thepolarbear.co.uk/feeds/videos.xml?videoChannelId=2";
                title = "PolarBear TV (Hamish's Peertube)";
              }
              {
                url = "https://video.thepolarbear.co.uk/feeds/videos.xml?videoChannelId=1344";
                title = "Fedi Player One (Chris Were's Peertube)";
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
