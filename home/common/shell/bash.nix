# home/common/shell/bash.nix
{...}: {
  flake.homeModules.home--shell--bash = {
    allHosts,
    flakePath,
    lib,
    pkgs,
    ...
  }: let
    bashFilesDir = "${flakePath}/home/files/bash";
    aliasesDir = "${bashFilesDir}/.bash/aliases";

    # Every *.sh file under aliases/, keyed by its own filename.
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
        ".bash_profile".source = "${bashFilesDir}/.bash_profile";
        ".bashrc".source = "${bashFilesDir}/.bashrc";

        ".bash/environment_variables".source = "${bashFilesDir}/.bash/environment_variables";
        ".bash/bash_prompt".source = "${bashFilesDir}/.bash/bash_prompt";
        ".bash/bash_functions".source = "${bashFilesDir}/.bash/bash_functions";
        ".bash/emoticons".source = "${bashFilesDir}/.bash/emoticons";

        ".bash/ghostty_theme_randomizer" = {
          source = "${bashFilesDir}/.bash/ghostty_theme_randomizer";
          executable = true;
        };

        # Generated file — stays hand-written since its content is dynamic,
        # not a static file on disk.
        ".bash/aliases/ssh.sh".source = pkgs.writeText "ssh.sh" ''
          # aliases/ssh.sh — SSH shortcuts generated from allHosts (managed by Nix)

          alias nixace='ssh  temhr@${allHosts.nixace.address}'
          alias nixnas1='ssh temhr@${allHosts.nixnas1.address}'
          alias nixnas2='ssh temhr@${allHosts.nixnas2.address}'
          alias nixsun='ssh  temhr@${allHosts.nixsun.address}'
          alias nixtop='ssh  temhr@${allHosts.nixtop.address}'
          alias nixvat='ssh  temhr@${allHosts.nixvat.address}'
          alias nixzen='ssh  temhr@${allHosts.nixzen.address}'
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
