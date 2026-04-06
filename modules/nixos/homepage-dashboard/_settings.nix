# /var/lib/homepage/config/settings.yaml
# Homepage general settings
# Docs: https://gethomepage.dev/en/configs/settings/
{hostMeta}: let
  # Mirror of the group membership from _services.nix.
  # A group only appears in layout if at least one of its service keys
  # is present in hostMeta.services.
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

  groupColumns = {
    "AI & Inference" = 3;
    "Knowledge & Docs" = 3;
    "Monitoring & Logs" = 3;
    "Home & Automation" = 2;
    "Sync and Storage" = 2;
    "Social & Feeds" = 2;
  };

  activeGroups =
    builtins.foldl'
    (
      acc: key: let
        group = serviceGroups.${key};
      in
        if builtins.elem key hostMeta.services && !(builtins.elem group acc)
        then acc ++ [group]
        else acc
    )
    []
    (builtins.attrNames serviceGroups);

  layoutEntries =
    builtins.foldl'
    (acc: group:
      acc
      // {
        ${group} = {
          style = "row";
          columns = groupColumns.${group};
        };
      })
    {}
    activeGroups;
in {
  title = "Home";

  # Colour theme — Tailwind palette name:
  # slate | gray | zinc | neutral | stone | red | orange | yellow
  # green | teal | blue | indigo | violet | fuchsia
  color = "slate";

  cardBlur = "sm";

  layout = layoutEntries;

  quicklaunch = {
    searchDescriptions = true;
    hideInternetSearch = false;
    showSearchSuggestions = true;
    target = "_blank";
  };

  log_level = "warn";
}
