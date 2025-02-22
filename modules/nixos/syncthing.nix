{ config, lib, ... }: {

    options = {
        syncace = {
            enable = lib.mkEnableOption {
              description = "Enables Syncthing on nixace";
              default = false;
            };
        };
        syncbase = {
            enable = lib.mkEnableOption {
              description = "Enables Syncthing on nixbase";
              default = false;
            };
        };
        syncser = {
            enable = lib.mkEnableOption {
              description = "Enables Syncthing on nixser";
              default = false;
            };
        };
        synctop = {
            enable = lib.mkEnableOption {
              description = "Enables Syncthing on nixtop";
              default = false;
            };
        };
    };

    config = lib.mkMerge [

        (lib.mkIf config.syncace.enable {
            systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder
            networking.firewall = {
                allowedTCPPorts = [ 8384 ];
                allowedUDPPorts = [ 8384 ];
            };
            services.syncthing = {
                # Enables the Syncthing Service
                #enable = true;
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
                        "nixbase" = { id = "5KHDLOC-2FKYN27-2FADIS5-FQTKXOE-B63AEEZ-BYDWKPJ-B24GQUC-6JXTAQP"; };
                        "nixser" = { id = "ZBEUAV6-DMJ4XD5-JYHK54G-U67C76K-V43FXHB-TWNAKA4-MQY7VSM-45LNDQH"; };
                        #"nixtop" = { id = "W7D7LC4-TFMJUFD-NXTAWDN-KCHXPEL-ACWWQES-VSBPGOH-BJDNLKC-PYZB7QW"; };
                    };
                    # all machines must have same declaration, but "devices" reflect the opposite device
                    folders = {
                        # Name of folder in Syncthing, also the folder ID
                        "home-nixace" = {
                        # Which folder to add to Syncthing
                            path = "/home/temhr";
                            # Which devices to share the folder with
                            devices = [ "nixser" ];
                        };
                    };
                };
            };
        })
        (lib.mkIf config.syncbase.enable {
            systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder
            networking.firewall = {
                allowedTCPPorts = [ 8384 ];
                allowedUDPPorts = [ 8384 ];
            };
            services.syncthing = {
                # Enables the Syncthing Service
                enable = true;
                # Sets the Data/default sync directory (but we won’t use this)
                dataDir = "/mirror";
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
                        #"nixace" = { id = "FWM4KIE-IRRB5P4-2PYUOEP-JNTOA6Q-IC6I7R5-IUJWWDL-D4HWF4X-DBONGA7"; };
                        "nixser" = { id = "ZBEUAV6-DMJ4XD5-JYHK54G-U67C76K-V43FXHB-TWNAKA4-MQY7VSM-45LNDQH"; };
                        #"nixtop" = { id = "W7D7LC4-TFMJUFD-NXTAWDN-KCHXPEL-ACWWQES-VSBPGOH-BJDNLKC-PYZB7QW"; };
                    };
                    # all machines must have same declaration, but "devices" reflect the opposite device
                    folders = {                        # Name of folder in Syncthing, also the folder ID
                    #    "home-nixbase" = {
                    #    # Which folder to add to Syncthing
                    #        path = "/home/temhr";
                    #        # Which devices to share the folder with
                    #        devices = [ "nixser" ];
                    #    };
                        # Name of folder in Syncthing, also the folder ID
                        "mirror" = {
                        path = "/mirror";
                        devices = [ "nixser" ];
                        };
                    };
                };
            };
        })
        (lib.mkIf config.syncser.enable {
            systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder
            networking.firewall = {
                allowedTCPPorts = [ 8384 ];
                allowedUDPPorts = [ 8384 ];
            };
            services.syncthing = {
                # Enables the Syncthing Service
                enable = true;
                # Sets the Data/default sync directory (but we won’t use this)
                dataDir = "/mirror";
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
                        #"nixace" = { id = "FWM4KIE-IRRB5P4-2PYUOEP-JNTOA6Q-IC6I7R5-IUJWWDL-D4HWF4X-DBONGA7"; };
                        "nixbase" = { id = "5KHDLOC-2FKYN27-2FADIS5-FQTKXOE-B63AEEZ-BYDWKPJ-B24GQUC-6JXTAQP"; };
                        #"nixtop" = { id = "W7D7LC4-TFMJUFD-NXTAWDN-KCHXPEL-ACWWQES-VSBPGOH-BJDNLKC-PYZB7QW"; };
                    };
                    # all machines must have same declaration, but "devices" reflect the opposite device
                    folders = {                        # Name of folder in Syncthing, also the folder ID
                    #    "home-nixser" = {
                    #    # Which folder to add to Syncthing
                    #        path = "/home/temhr";
                    #        # Which devices to share the folder with
                    #        devices = [ "nixbase" ];
                    #    };
                        # Name of folder in Syncthing, also the folder ID
                        "mirror" = {
                        path = "/mirror";
                        devices = [ "nixbase" ];
                        };
                    };
                };
            };
        })
        (lib.mkIf config.synctop.enable {
            systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder
            networking.firewall = {
                allowedTCPPorts = [ 8384 ];
                allowedUDPPorts = [ 8384 ];
            };
            services.syncthing = {
                # Enables the Syncthing Service
                #enable = true;
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
                        "nixace" = { id = "FWM4KIE-IRRB5P4-2PYUOEP-JNTOA6Q-IC6I7R5-IUJWWDL-D4HWF4X-DBONGA7"; };
                        "nixbase" = { id = "5KHDLOC-2FKYN27-2FADIS5-FQTKXOE-B63AEEZ-BYDWKPJ-B24GQUC-6JXTAQP"; };
                        #"nixser" = { id = "ZBEUAV6-DMJ4XD5-JYHK54G-U67C76K-V43FXHB-TWNAKA4-MQY7VSM-45LNDQH"; };
                    };
                    # all machines must have same declaration, but "devices" reflect the opposite device
                    folders = {
                        # Name of folder in Syncthing, also the folder ID
                        "home-nixtop" = {
                        # Which folder to add to Syncthing
                            path = "/home/temhr";
                            # Which devices to share the folder with
                            devices = [ "nixser" ];
                        };
                    };
                };
            };
        })
    ];

}
