# /var/lib/homepage/config/settings.yaml
# Homepage general settings
# Docs: https://gethomepage.dev/en/configs/settings/
{config}: let
  registry = import ./_service-registry.nix {inherit config;};

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
        group = registry.groups.${key};
      in
        if (registry.enabled.${key} or false) && !(builtins.elem group acc)
        then acc ++ [group]
        else acc
    )
    []
    (builtins.attrNames registry.groups);

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
    target = "";
  };

  log_level = "warn";
}
