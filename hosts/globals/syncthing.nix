{ config, lib, ... }: {

    options = {
        syncace = {
            enable = lib.mkEnableOption "enables Syncthing on nixace";
        };
        syncbase = {
            enable = lib.mkEnableOption "enables Syncthing on nixbase";
        };
        synctop = {
            enable = lib.mkEnableOption "enables Syncthing on nixtop";
        };
    };

    config = lib.mkMerge [

        (lib.mkIf config.syncace.enable {
            services.syncthing = {
                # Enables the Syncthing Service
                enable = true;
                # Sets the Data/default sync directory (but we won’t use this)
                #dataDir = "/home/temhr";
                # Opens the default ports (21027/tcp & 22000) - note this doesn’t include the web interface
                openDefaultPorts = true;
                # Sets the Config Directory (important part of .config files)
                configDir = "/home/temhr/.config/syncthing";
                # Sets the user that Syncthing runs as
                user = "temhr";
                # Sets the group that Syncthing runs as
                group = "users";
                # Sets the Web Interface to listen on all interfaces (headless 0.0.0.0, otherwise 127.0.0.1)
                guiAddress = "0.0.0.0:8384";
                # Override the devices / folders that are configured in the web interface
                overrideDevices = true;
                overrideFolders = true;
                settings = {
                    # Manually grab the device IDs of the other syncthing devices
                    devices = {
                        "pve" = { id = "AG43EPZ-VGVQGHH-WABHCQF-3M4VXSB-7G6J3J6-OWHNULZ-IXIK3TJ-TGZX7Q4"; };
                        "nixbase" = { id = "5KHDLOC-2FKYN27-2FADIS5-FQTKXOE-B63AEEZ-BYDWKPJ-B24GQUC-6JXTAQP"; };
                        "nixtop" = { id = "W7D7LC4-TFMJUFD-NXTAWDN-KCHXPEL-ACWWQES-VSBPGOH-BJDNLKC-PYZB7QW"; };
                    };
                    # all machines must have same declaration, but "devices" reflect the opposite device
                    folders = {
                        # Name of folder in Syncthing, also the folder ID
                        "home-nixace" = {
                        # Which folder to add to Syncthing
                            path = "/home/temhr";
                            # Which devices to share the folder with
                            devices = [ "pve" ];
                            # optional, keeps all changes to files for 180 days
                            versioning = {
                                type = "staggered";
                                params = {
                                    cleanInterval = "3600"; # 1 hour in seconds
                                    maxAge = "15768000"; # 180 days in seconds
                                };
                            };
                        };
                    };
                };
            };
        })
        (lib.mkIf config.syncbase.enable {
            services.syncthing = {
                # Enables the Syncthing Service
                enable = true;
                # Sets the Data/default sync directory (but we won’t use this)
                #dataDir = "/home/temhr";
                # Opens the default ports (21027/tcp & 22000) - note this doesn’t include the web interface
                openDefaultPorts = true;
                # Sets the Config Directory (important part of .config files)
                configDir = "/home/temhr/.config/syncthing";
                # Sets the user that Syncthing runs as
                user = "temhr";
                # Sets the group that Syncthing runs as
                group = "users";
                # Sets the Web Interface to listen on all interfaces (headless 0.0.0.0, otherwise 127.0.0.1)
                guiAddress = "0.0.0.0:8384";
                # Override the devices / folders that are configured in the web interface
                overrideDevices = true;
                overrideFolders = true;
                settings = {
                # Manually grab the device IDs of the other syncthing devices
                devices = {
                    "pve" = { id = "AG43EPZ-VGVQGHH-WABHCQF-3M4VXSB-7G6J3J6-OWHNULZ-IXIK3TJ-TGZX7Q4"; };
                    "nixace" = { id = "MMNJWSJ-7MDL6F3-XQYWKWM-JX77ZH7-SZ4U7UT-ZP6D47B-XLYRYFZ-3F3BXQK"; };
                    "nixtop" = { id = "W7D7LC4-TFMJUFD-NXTAWDN-KCHXPEL-ACWWQES-VSBPGOH-BJDNLKC-PYZB7QW"; };
                };
                # all machines must have same declaration, but "devices" reflect the opposite device
                folders = {
                    # Name of folder in Syncthing, also the folder ID
                    "home-nixbase" = {
                    # Which folder to add to Syncthing
                    path = "/home/temhr";
                    # Which devices to share the folder with
                    devices = [ "pve" ];
                    # optional, keeps all changes to files for 180 days
                    versioning = {
                        type = "staggered";
                        params = {
                        cleanInterval = "3600"; # 1 hour in seconds
                        maxAge = "15768000"; # 180 days in seconds
                        };
                    };
                    };
                    "mirror" = {
                    path = "/run/media/temhr/HGST";
                    devices = [ "pve" ];
                    };
                };
                };
            };
        })
        (lib.mkIf config.synctop.enable {
            services.syncthing = {
                # Enables the Syncthing Service
                enable = true;
                # Sets the Data/default sync directory (but we won’t use this)
                #dataDir = "/home/temhr";
                # Opens the default ports (21027/tcp & 22000) - note this doesn’t include the web interface
                openDefaultPorts = true;
                # Sets the Config Directory (important part of .config files)
                configDir = "/home/temhr/.config/syncthing";
                # Sets the user that Syncthing runs as
                user = "temhr";
                # Sets the group that Syncthing runs as
                group = "users";
                # Sets the Web Interface to listen on all interfaces (headless 0.0.0.0, otherwise 127.0.0.1)
                guiAddress = "0.0.0.0:8384";
                # Override the devices / folders that are configured in the web interface
                overrideDevices = true;
                overrideFolders = true;
                settings = {
                    # Manually grab the device IDs of the other syncthing devices
                    devices = {
                        "pve" = { id = "AG43EPZ-VGVQGHH-WABHCQF-3M4VXSB-7G6J3J6-OWHNULZ-IXIK3TJ-TGZX7Q4"; };
                        "nixace" = { id = "MMNJWSJ-7MDL6F3-XQYWKWM-JX77ZH7-SZ4U7UT-ZP6D47B-XLYRYFZ-3F3BXQK"; };
                        "nixbase" = { id = "5KHDLOC-2FKYN27-2FADIS5-FQTKXOE-B63AEEZ-BYDWKPJ-B24GQUC-6JXTAQP"; };
                    };
                    # all machines must have same declaration, but "devices" reflect the opposite device
                    folders = {
                        # Name of folder in Syncthing, also the folder ID
                        "home-nixtop" = {
                        # Which folder to add to Syncthing
                            path = "/home/temhr";
                            # Which devices to share the folder with
                            devices = [ "pve" ];
                            # optional, keeps all changes to files for 180 days
                            versioning = {
                                type = "staggered";
                                params = {
                                    cleanInterval = "3600"; # 1 hour in seconds
                                    maxAge = "15768000"; # 180 days in seconds
                                };
                            };
                        };
                    };
                };
            };
        })
    ];

}
