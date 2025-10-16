{ lib, ... }: {

  home.sessionVariables = {
    # XDG User Directories
    XDG_DESKTOP_DIR      = "$HOME/shelf/default/Desktop";      # Graphical desktop files
    XDG_DOCUMENTS_DIR    = "$HOME/shelf/default/Documents";    # Text and document files
    XDG_DOWNLOAD_DIR     = "$HOME/shelf/default/Downloads";    # Default download location
    XDG_MUSIC_DIR        = "$HOME/shelf/default/Music";        # Audio and music files
    XDG_PICTURES_DIR     = "$HOME/shelf/default/Pictures";     # Images and photos
    XDG_VIDEOS_DIR       = "$HOME/shelf/default/Videos";       # Video and media files
    XDG_TEMPLATES_DIR    = "$HOME/shelf/default/Templates";    # Document templates
    XDG_PUBLICSHARE_DIR  = "$HOME/shelf/default/Public";       # Files for public sharing

    # Development Directories (custom extensions)
    XDG_PROJECTS_DIR     = "$HOME/shelf/projects";     # Personal or exploratory work
    XDG_CODE_DIR         = "$HOME/shelf/code";         # Long-term or serious repositories
    XDG_QEMU_DIR         = "$HOME/shelf/qemu";         # VM's and Containers
  };

  # Create XDG directories safely at activation
  home.activation.createXDGDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Ensuring XDG user and development directories exist..."

    # Define paths explicitly (since sessionVariables are not sourced here)
    XDG_BASE="$HOME/shelf"
    dirs=(
      "$XDG_BASE/default/Desktop"
      "$XDG_BASE/default/Documents"
      "$XDG_BASE/default/Downloads"
      "$XDG_BASE/default/Music"
      "$XDG_BASE/default/Pictures"
      "$XDG_BASE/default/Videos"
      "$XDG_BASE/default/Templates"
      "$XDG_BASE/default/Public"
      "$XDG_BASE/projects"
      "$XDG_BASE/code"
      "$XDG_BASE/qemu"
    )

    for d in "''${dirs[@]}"; do
      if [ ! -d "$d" ]; then
        mkdir -p "$d"
        echo "Created: $d"
      fi
    done

    echo "✅ XDG directories verified or created."
  '';
}
