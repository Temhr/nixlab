{ ... }: {

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
  };

  # Ensure XDG directories exist at activation
  home.activation.createXDGDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Ensuring XDG user and development directories exist..."

    mkdir -p \
      "$XDG_DESKTOP_DIR" \
      "$XDG_DOCUMENTS_DIR" \
      "$XDG_DOWNLOAD_DIR" \
      "$XDG_MUSIC_DIR" \
      "$XDG_PICTURES_DIR" \
      "$XDG_VIDEOS_DIR" \
      "$XDG_TEMPLATES_DIR" \
      "$XDG_PUBLICSHARE_DIR" \
      "$XDG_PROJECTS_DIR" \
      "$XDG_CODE_DIR"

    echo "✅ XDG directories verified or created."
  '';
}
