{...}: {
  flake.nixosModules.servc--rustdesk-nixlab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.rustdesk-nixlab;

    # ----------------------------------------------------------------------------
    # HELPERS
    # ----------------------------------------------------------------------------

    # Builds the RustDesk client config file written to
    # ~/.config/rustdesk/RustDesk2.toml — used by both `remote` and `client`.
    mkClientConfig = connCfg: ''
      rendezvous_server = '${connCfg.idServer}'
      nat_type = 1
      serial = 0

      [options]
      custom-rendezvous-server = '${connCfg.idServer}'
      relay-server = '${connCfg.relayServer}'
      api-server = ' '
      key = '${connCfg.publicKey}'
      direct-server = 'Y'
      direct-access-port = '21118'
    '';

    # Shared connection sub-options reused by both `remote` and `client`
    mkConnectionOptions = desc: {
      idServer = lib.mkOption {
        type = lib.types.str;
        example = "192.168.1.10";
        description = "IP or domain of the hbbs ID/rendezvous server. ${desc}";
      };
      relayServer = lib.mkOption {
        type = lib.types.str;
        example = "192.168.1.10";
        description = "IP or domain of the hbbr relay server. ${desc}";
      };
      publicKey = lib.mkOption {
        type = lib.types.str;
        example = "abc123...";
        description = ''
          Public key from the server (contents of /var/lib/rustdesk/id_ed25519.pub).
          ${desc}
        '';
      };
    };
  in {
    # ============================================================================
    # OPTIONS
    # ============================================================================
    options = {
      services.rustdesk-nixlab = {
        # REQUIRED: Enable the module
        enable = lib.mkEnableOption "RustDesk self-hosted remote desktop server";

        # OPTIONAL: Server-side package (hbbs/hbbr binaries)
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.rustdesk-server;
          defaultText = lib.literalExpression "pkgs.rustdesk-server";
          description = "The rustdesk-server package (hbbs/hbbr binaries)";
        };

        # OPTIONAL: GUI client package
        clientPackage = lib.mkOption {
          type = lib.types.package;
          default = pkgs.rustdesk;
          defaultText = lib.literalExpression "pkgs.rustdesk";
          description = "The RustDesk GUI client package";
        };

        # OPTIONAL: Where server stores its keypair and relay state
        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/rustdesk";
          description = "Directory for RustDesk server data (keys, relay state)";
        };

        # ----------------------------------------------------------------------------
        # HBBS - Rendezvous / ID server
        # ----------------------------------------------------------------------------
        hbbs = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable the hbbs rendezvous/ID server";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 21115;
            description = "Base port for hbbs. Also binds port+1 (21116) for ID/relay.";
          };

          # NOTE: rustdesk-server 1.1.x does not support binding to a specific
          # interface — hbbs always listens on 0.0.0.0. Use firewall to restrict.

          relayServer = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "relay.example.com";
            description = ''
              Address of the hbbr relay server to advertise to clients.
              If null, defaults to the same host as hbbs.
            '';
          };
        };

        # ----------------------------------------------------------------------------
        # HBBR - Relay server
        # ----------------------------------------------------------------------------
        hbbr = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable the hbbr relay server";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 21117;
            description = "Port for hbbr relay server";
          };

          # NOTE: rustdesk-server 1.1.x does not support binding to a specific
          # interface — hbbr always listens on 0.0.0.0. Use firewall to restrict.
        };

        # ----------------------------------------------------------------------------
        # REMOTE - Always-on controlled side (this machine can be connected TO)
        #
        # Installs the RustDesk client and runs it as a persistent systemd user
        # service so the machine is always reachable, even without an active
        # interactive session. `loginctl enable-linger` is set automatically so
        # the user service survives across logouts.
        #
        # Requires a graphical session (X11 or Wayland) to be available —
        # RustDesk needs a display to share.
        # ----------------------------------------------------------------------------
        remote = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Enable always-on remote access for this machine.
              Installs the RustDesk client and runs it as a persistent
              systemd user service so the machine is always connectable.
            '';
          };

          user = lib.mkOption {
            type = lib.types.str;
            default = config.nixlab.mainUser;
            description = ''
              The user whose session is shared over remote access.
              The RustDesk daemon runs under this user account.
            '';
          };

          autostart = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Automatically start the remote daemon on login / at boot";
          };

          connection =
            mkConnectionOptions
            "Used to register this machine with your RustDesk server.";
        };

        # ----------------------------------------------------------------------------
        # CLIENT - Workstation side (this machine connects TO others)
        #
        # Installs the RustDesk GUI app and pre-populates each specified user's
        # config file so the app is pointed at your server immediately after
        # deploy — no manual setup needed.
        #
        # The config file is only written if it doesn't already exist, so
        # existing user customisations are never overwritten.
        # ----------------------------------------------------------------------------
        client = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Install and pre-configure the RustDesk GUI client on this machine.
              Writes server connection details for each user so the app is
              ready to use immediately without manual configuration.
            '';
          };

          users = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [config.nixlab.mainUser];
            description = "Users to pre-configure the RustDesk client for";
          };

          connection =
            mkConnectionOptions
            "Pre-populated into each user's client config so the app is ready immediately.";
        };

        # ----------------------------------------------------------------------------
        # NGINX REVERSE PROXY - Optional
        # ----------------------------------------------------------------------------
        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "rustdesk.example.com";
          description = "Domain name for nginx reverse proxy (optional)";
        };

        enableSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HTTPS with Let's Encrypt (requires domain to be set)";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open firewall ports required by hbbs and hbbr";
        };
      };
    };

    # ============================================================================
    # CONFIG
    # ============================================================================
    config = lib.mkIf cfg.enable {
      # ----------------------------------------------------------------------------
      # SERVER: Dedicated system user + data directory
      # ----------------------------------------------------------------------------
      users.users.rustdesk = {
        isSystemUser = true;
        group = "rustdesk";
        home = cfg.dataDir;
        createHome = true;
        description = "RustDesk server daemon user";
      };

      users.groups.rustdesk = {};
      users.users.${config.nixlab.mainUser}.extraGroups = ["rustdesk"];

      system.activationScripts.initRustdeskDir = {
        text = ''
          DATA_DIR="${cfg.dataDir}"
          mkdir -p "$DATA_DIR"
          chown -R rustdesk:rustdesk "$DATA_DIR"
          chmod 750 "$DATA_DIR"
        '';
      };

      # ----------------------------------------------------------------------------
      # SERVER: hbbs
      # ----------------------------------------------------------------------------
      systemd.services.rustdesk-hbbs = lib.mkIf cfg.hbbs.enable {
        description = "RustDesk hbbs Rendezvous/ID Server";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];

        serviceConfig = {
          Type = "simple";
          User = "rustdesk";
          Group = "rustdesk";
          WorkingDirectory = cfg.dataDir;

          ExecStart = let
            relayArg =
              if cfg.hbbs.relayServer != null
              then " -r ${cfg.hbbs.relayServer}:${toString cfg.hbbr.port}"
              else "";
          in "${cfg.package}/bin/hbbs -p ${toString cfg.hbbs.port}${relayArg}";

          Restart = "on-failure";
          RestartSec = "10s";
          ReadWritePaths = [cfg.dataDir];
        };
      };

      # ----------------------------------------------------------------------------
      # SERVER: hbbr
      # ----------------------------------------------------------------------------
      systemd.services.rustdesk-hbbr = lib.mkIf cfg.hbbr.enable {
        description = "RustDesk hbbr Relay Server";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];

        serviceConfig = {
          Type = "simple";
          User = "rustdesk";
          Group = "rustdesk";
          WorkingDirectory = cfg.dataDir;

          ExecStart = "${cfg.package}/bin/hbbr -p ${toString cfg.hbbr.port}";

          Restart = "on-failure";
          RestartSec = "10s";
          ReadWritePaths = [cfg.dataDir];
        };
      };

      # ----------------------------------------------------------------------------
      # REMOTE: Install client + write config + enable linger + user service
      # ----------------------------------------------------------------------------

      system.activationScripts.rustdeskRemoteConfig = lib.mkIf cfg.remote.enable {
        text = ''
          REMOTE_USER="${cfg.remote.user}"
          CONFIG_DIR="/home/$REMOTE_USER/.config/rustdesk"
          mkdir -p "$CONFIG_DIR"

          cat > "$CONFIG_DIR/RustDesk2.toml" << 'RDEOF'
          ${mkClientConfig cfg.remote.connection}
          RDEOF

          chown -R "$REMOTE_USER:$REMOTE_USER" "$CONFIG_DIR"
          chmod 600 "$CONFIG_DIR/RustDesk2.toml"
        '';
      };

      # Enable linger so the user service starts at boot without an interactive login
      system.activationScripts.rustdeskRemoteLinger = lib.mkIf cfg.remote.enable {
        text = ''
          loginctl enable-linger ${cfg.remote.user}
        '';
      };

      # Persistent systemd user service — runs under cfg.remote.user's session
      systemd.user.services.rustdesk-remote = lib.mkIf cfg.remote.enable {
        description = "RustDesk Always-On Remote Daemon";
        wantedBy = ["default.target"];
        after = ["graphical-session.target"];
        partOf = ["graphical-session.target"];

        serviceConfig = {
          Type = "simple";
          ExecStart = "${cfg.clientPackage}/bin/rustdesk --service";
          Restart = "on-failure";
          RestartSec = "10s";
          TimeoutStartSec = "30s";
        };

        enable = cfg.remote.autostart;
      };

      # ----------------------------------------------------------------------------
      # REMOTE + CLIENT: Install GUI client when either role is enabled
      # (single merged assignment avoids duplicate attribute error)
      # ----------------------------------------------------------------------------
      environment.systemPackages =
        lib.optionals cfg.remote.enable [cfg.clientPackage]
        ++ lib.optionals cfg.client.enable [cfg.clientPackage];

      # CLIENT: Write per-user config (only if not already present)

      system.activationScripts.rustdeskClientConfig = lib.mkIf cfg.client.enable {
        text = ''
          ${lib.concatMapStrings (user: ''
                CLIENT_CONFIG_DIR="/home/${user}/.config/rustdesk"
                mkdir -p "$CLIENT_CONFIG_DIR"

                # Only write if config doesn't already exist — preserve user changes
                if [ ! -f "$CLIENT_CONFIG_DIR/RustDesk2.toml" ]; then
                  cat > "$CLIENT_CONFIG_DIR/RustDesk2.toml" << 'RDEOF'
              ${mkClientConfig cfg.client.connection}
              RDEOF
                  chown -R "${user}:${user}" "$CLIENT_CONFIG_DIR"
                  chmod 600 "$CLIENT_CONFIG_DIR/RustDesk2.toml"
                  echo "RustDesk client configured for ${user}"
                fi
            '')
            cfg.client.users}
        '';
      };

      # ----------------------------------------------------------------------------
      # NGINX REVERSE PROXY
      # ----------------------------------------------------------------------------
      services.nginx.enable = lib.mkIf (cfg.domain != null) true;

      services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
        ${cfg.domain} = {
          forceSSL = cfg.enableSSL;
          enableACME = cfg.enableSSL;

          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.hbbs.port}";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
      };

      # ----------------------------------------------------------------------------
      # FIREWALL
      #
      #   hbbs: 21115 (TCP)       - NAT type test
      #         21116 (TCP + UDP) - ID server + hole-punching
      #         21118 (TCP)       - Web client (optional)
      #   hbbr: 21117 (TCP)       - Relay
      #         21119 (TCP)       - Web client relay (optional)
      # ----------------------------------------------------------------------------
      networking.firewall = lib.mkIf cfg.openFirewall {
        allowedTCPPorts =
          lib.optionals cfg.hbbs.enable [
            cfg.hbbs.port # 21115 - NAT test
            (cfg.hbbs.port + 1) # 21116 - ID server
            (cfg.hbbs.port + 3) # 21118 - Web client
          ]
          ++ lib.optionals cfg.hbbr.enable [
            cfg.hbbr.port # 21117 - Relay
            (cfg.hbbr.port + 2) # 21119 - Web client relay
          ]
          ++ lib.optionals (cfg.domain != null) [80 443];

        allowedUDPPorts = lib.optionals cfg.hbbs.enable [
          (cfg.hbbs.port + 1) # 21116 - hole-punching
        ];
      };
    };
  };
}
/*
================================================================================
USAGE EXAMPLES
================================================================================

1. Dedicated server machine (hbbs + hbbr only, no client):
-----------------------------------------------------------
services.rustdesk-nixlab = {
  enable = true;
};
# After deploy: cat /var/lib/rustdesk/id_ed25519.pub


2. Workstation — client only (connects to others, not reachable itself):
------------------------------------------------------------------------
services.rustdesk-nixlab = {
  enable = true;
  hbbs.enable = false;
  hbbr.enable = false;

  client = {
    enable = true;
    connection = {
      idServer    = "192.168.1.10";
      relayServer = "192.168.1.10";
      publicKey   = "your-public-key-here";
    };
  };
};


3. Headless machine — always-on remote (can be connected TO, no GUI client):
----------------------------------------------------------------------------
services.rustdesk-nixlab = {
  enable = true;
  hbbs.enable = false;
  hbbr.enable = false;

  remote = {
    enable    = true;
    user      = "alice";
    autostart = true;
    connection = {
      idServer    = "192.168.1.10";
      relayServer = "192.168.1.10";
      publicKey   = "your-public-key-here";
    };
  };
};


4. Full fleet machine — connects to others AND can be connected to:
-------------------------------------------------------------------
services.rustdesk-nixlab = {
  enable = true;
  hbbs.enable = false;
  hbbr.enable = false;

  client = {
    enable = true;
    users  = [ "alice" "bob" ];   # pre-configure for multiple users
    connection = {
      idServer    = "192.168.1.10";
      relayServer = "192.168.1.10";
      publicKey   = "your-public-key-here";
    };
  };

  remote = {
    enable = true;
    user   = "alice";             # whose desktop is shared
    connection = {
      idServer    = "192.168.1.10";
      relayServer = "192.168.1.10";
      publicKey   = "your-public-key-here";
    };
  };
};


5. All-in-one — server + client + remote on the same machine:
-------------------------------------------------------------
services.rustdesk-nixlab = {
  enable       = true;
  openFirewall = true;

  client = {
    enable = true;
    connection = {
      idServer    = "localhost";
      relayServer = "localhost";
      publicKey   = "your-public-key-here";
    };
  };

  remote = {
    enable = true;
    connection = {
      idServer    = "localhost";
      relayServer = "localhost";
      publicKey   = "your-public-key-here";
    };
  };
};
*/

