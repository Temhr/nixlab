{ pkgs, ... }: {

#1) User-specific
#2) Don’t require elevated privileges
#3) Part of user workflows

  home.packages = with pkgs; [
    ## Terminal Utilities
    bat              # cat clone with syntax highlighting
    colordiff        # colorful diff output wrapper
    eza              # modern replacement for `ls`
    fastfetch        # fast system info fetcher (like neofetch)
    fzf              # fuzzy finder for terminal
    jq               # command-line JSON processor
    less             # terminal file pager
    screen           # terminal multiplexer (scrollback, multiple sessions)
    tmux             # terminal multiplexer with scripting support
    tealdeer         # fast TL;DR pages for common CLI tools
    moreutils        # additional useful Unix tools (e.g., `sponge`, `ts`)
    zoxide           # smarter `cd` replacement with frecency tracking

    ## Text Editors
    nano             # simple, user-friendly terminal text editor
    vim              # powerful, modal terminal text editor
    neovim           # modern fork of vim with better extensibility
    alejandra        # opinionated and fast Nix code formatter
    zed              # structured data lake & search engine (experimental)

    ## Terminal File Managers
    mc               # Midnight Commander, ncurses-based file manager
    # ranger         # minimal ncurses file manager with VI keybindings
    # lf             # minimalist file manager inspired by ranger
    # nnn            # very fast, minimal terminal file browser
    # vifm-full      # vi-like file manager
    # yazi           # async Rust file manager with previews

    ## Device/Info (safe for user)
    ncdu             # ncurses-based disk usage viewer
    clinfo           # lists OpenCL devices and capabilities
    glxinfo          # OpenGL renderer and extension information
    #kdePackages.filelight  # GUI disk usage visualizer using concentric rings

    ## Applications
    kdePackages.kcalc        # scientific calculator GUI
    #ffmpeg                   # command-line audio/video converter
    scrcpy                   # mirror and control Android devices
    simplescreenrecorder     # GUI screen recorder for X11
    keepassxc                # secure offline password manager
  ];
}
