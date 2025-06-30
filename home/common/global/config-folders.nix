{  config, ... }: {

    xdg.userDirs = {
        enable = true;
        desktop = "${config.home.homeDirectory}/shelf/Desktop";
        documents = "${config.home.homeDirectory}/shelf/Documents";
        download = "${config.home.homeDirectory}/shelf/Downloads";
        music = "${config.home.homeDirectory}/shelf/Music";
        pictures = "${config.home.homeDirectory}/shelf/Pictures";
        videos = "${config.home.homeDirectory}/shelf/Videos";
        templates = "${config.home.homeDirectory}/shelf/Templates";
        publicShare = "${config.home.homeDirectory}/shelf/Public";
    };
}
