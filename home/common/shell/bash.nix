# home/common/shell/bash.nix
{...}: {
  flake.homeModules.home--shell--bash = {
    allHosts,
    config,
    flakePath,
    lib,
    pkgs,
    ...
  }: let
    bashFilesDir = "${flakePath}/home/files/bash";
    aliasesDir = "${bashFilesDir}/.bash/aliases";

    aliasFileNames =
      builtins.attrNames
      (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".sh" name)
        (builtins.readDir aliasesDir));

    aliasHomeFiles =
      lib.genAttrs
      (map (n: ".bash/aliases/${n}") aliasFileNames)
      (path: let
        n = builtins.baseNameOf path;
      in {source = "${aliasesDir}/${n}";});
  in {
    home.file =
      {
        # These two collide with home-manager's own programs.bash module —
        # mkForce is genuinely necessary here, not blanket copy-paste.
        ".bash_profile".source = lib.mkForce "${bashFilesDir}/.bash_profile";
        ".bashrc".source = lib.mkForce "${bashFilesDir}/.bashrc";

        # Nothing else here is touched by any upstream module — plain
        # assignment is correct and sufficient.
        ".bash/environment_variables".source = "${bashFilesDir}/.bash/environment_variables";
        ".bash/bash_prompt".source = "${bashFilesDir}/.bash/bash_prompt";
        ".bash/bash_functions".source = "${bashFilesDir}/.bash/bash_functions";
        ".bash/emoticons".source = "${bashFilesDir}/.bash/emoticons";

        ".bash/ghostty_theme_randomizer" = {
          source = "${bashFilesDir}/.bash/ghostty_theme_randomizer";
          executable = true;
        };

        ".bash/aliases/ssh.sh".source = pkgs.writeText "ssh.sh" ''
          # aliases/ssh.sh — SSH shortcuts generated from allHosts (managed by Nix)

          alias nixace='ssh  ${config.home.username}@${allHosts.nixace.address}'
          alias nixnas1='ssh ${config.home.username}@${allHosts.nixnas1.address}'
          alias nixnas2='ssh ${config.home.username}@${allHosts.nixnas2.address}'
          alias nixsun='ssh  ${config.home.username}@${allHosts.nixsun.address}'
          alias nixtop='ssh  ${config.home.username}@${allHosts.nixtop.address}'
          alias nixvat='ssh  ${config.home.username}@${allHosts.nixvat.address}'
          alias nixzen='ssh  ${config.home.username}@${allHosts.nixzen.address}'
        '';
      }
      // aliasHomeFiles;

    programs.bash = {
      enable = true;
      historySize = 50000;
      historyFileSize = 100000;
      historyControl = ["ignoredups" "ignorespace" "erasedups"];
    };
  };
}
