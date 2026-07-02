{...}: {
  flake.homeModules.common-optional--bash-files-symlink = {
    allHosts,
    flakePath,
    lib,
    pkgs,
    ...
  }: {
    home.file = {
      # ── Root-level bash entry points ──────────────────────────────────────────
      ".bash_profile".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash_profile";
      ".bashrc".source = lib.mkForce "${flakePath}/home/common/files/bash/.bashrc";

      # ── Core .bash/ modules ───────────────────────────────────────────────────
      ".bash/environment_variables".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/environment_variables";
      ".bash/bash_prompt".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/bash_prompt";
      ".bash/bash_functions".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/bash_functions";
      ".bash/emoticons".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/emoticons";

      # Ghostty theme randomizer needs execute permission
      ".bash/ghostty_theme_randomizer" = {
        source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/ghostty_theme_randomizer";
        executable = true;
      };

      # ── Alias domain files ────────────────────────────────────────────────────
      ".bash/aliases/navigation.sh".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/aliases/navigation.sh";
      ".bash/aliases/files.sh".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/aliases/files.sh";
      ".bash/aliases/system.sh".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/aliases/system.sh";
      ".bash/aliases/network.sh".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/aliases/network.sh";
      ".bash/aliases/git.sh".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/aliases/git.sh";
      ".bash/aliases/nix.sh".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/aliases/nix.sh";
      ".bash/aliases/scrcpy.sh".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/aliases/scrcpy.sh";
      ".bash/aliases/powertools.sh".source = lib.mkForce "${flakePath}/home/common/files/bash/.bash/aliases/powertools.sh";

      # SSH shortcuts — dynamically generated from allHosts, appended to a
      # dedicated file so the other alias files stay static and version-controlled
      ".bash/aliases/ssh.sh".source = lib.mkForce (
        pkgs.writeText "ssh.sh" ''
          # aliases/ssh.sh — SSH shortcuts generated from allHosts (managed by Nix)

          alias nixace='ssh  temhr@${allHosts.nixace.address}'
          alias nixnas1='ssh temhr@${allHosts.nixnas1.address}'
          alias nixnas2='ssh temhr@${allHosts.nixnas2.address}'
          alias nixsun='ssh  temhr@${allHosts.nixsun.address}'
          alias nixtop='ssh  temhr@${allHosts.nixtop.address}'
          alias nixvat='ssh  temhr@${allHosts.nixvat.address}'
          alias nixzen='ssh  temhr@${allHosts.nixzen.address}'
        ''
      );
    };

    # ── Home Manager bash integration ─────────────────────────────────────────
    programs.bash = {
      enable = true;

      # Large history so you can always find that command you ran 3 weeks ago
      historySize = 50000;
      historyFileSize = 100000;
      historyControl = ["ignoredups" "ignorespace" "erasedups"];
    };
  };
}
