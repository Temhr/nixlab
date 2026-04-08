{...}: {
  flake.nixosModules.servc--rustdesk-nixlab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.rustdesk-nixlab;

    # ============================================================================
    # HELPERS
    # ============================================================================

    # --------------------------------------------------------------------------
    # PEER ID DERIVATION
    #
    # RustDesk IDs must be numeric strings in the range 100000000-999999999.
    # We derive a stable ID from the hostname by:
    #   1. MD5-hashing the hostname (gives a hex string)
    #   2. Taking the first 8 hex chars and converting to decimal
    #   3. Clamping to the valid range by mapping into 100000000-999999999
    #
    # This is pure Nix — evaluated at build time, no runtime dependencies.
    # --------------------------------------------------------------------------
    deriveId = hostname: let
      # md5 hex string → first 8 chars → parse as base-16 integer
      hash = builtins.hashString "md5" hostname;
      hexPart = builtins.substring 0 8 hash;
      # Nix doesn't have a built-in hex parser, so we convert manually
      hexDigit = c:
        if c == "0"
        then 0
        else if c == "1"
        then 1
        else if c == "2"
        then 2
        else if c == "3"
        then 3
        else if c == "4"
        then 4
        else if c == "5"
        then 5
        else if c == "6"
        then 6
        else if c == "7"
        then 7
        else if c == "8"
        then 8
        else if c == "9"
        then 9
        else if c == "a"
        then 10
        else if c == "b"
        then 11
        else if c == "c"
        then 12
        else if c == "d"
        then 13
        else if c == "e"
        then 14
        else if c == "f"
        then 15
        else 0;
      chars = lib.stringToCharacters hexPart;
      asInt = lib.foldl (acc: c: acc * 16 + hexDigit c) 0 chars;
      # Clamp to 100000000-999999999 (9 digits)
      range = 999999999 - 100000000;
      clamped = 100000000 + (lib.mod asInt range);
    in
      toString clamped;

    # This machine's own derived ID
    thisId = deriveId config.networking.hostName;

    # Peers list with IDs derived from hostnames, excluding this machine
    resolvedPeers =
      lib.filter
      (p: p.hostname != config.networking.hostName)
      (map (p: p // {id = deriveId p.hostname;}) cfg.peers);

    # Render the [peers] section of RustDesk2.toml
    # Format: alias = { id = '...', username = '', hostname = '', platform = '', alias = '...' }
    renderPeersSection =
      if resolvedPeers == []
      then ""
      else
        "[peers]
"
        + lib.concatMapStrings (p: ''
          ${p.hostname} = { id = "${p.id}", username = "", hostname = "${p.hostname}", platform = "", alias = "${p.alias or p.hostname}" }
        '')
        resolvedPeers;

    # --------------------------------------------------------------------------
    # SCRIPT HELPERS
    # --------------------------------------------------------------------------

    # Resolves the public key into $RUSTDESK_KEY at shell runtime.
    # - autoKey=true:  reads id_ed25519.pub from dataDir; empty if not yet generated
    # - autoKey=false: uses the publicKey option value verbatim
    resolveKeyScript =
      if cfg.connection.autoKey
      then ''
        KEY_FILE="${cfg.dataDir}/id_ed25519.pub"
        if [ -f "$KEY_FILE" ]; then
          RUSTDESK_KEY="$(cat "$KEY_FILE")"
        else
          echo "rustdesk-nixlab: key file not yet present at $KEY_FILE (hbbs not run yet?)"
          echo "                 Writing config without key — rustdesk-keypopulate.service"
          echo "                 will fill it in after hbbs generates the keypair."
          RUSTDESK_KEY=""
        fi
      ''
      else ''
        RUSTDESK_KEY="${cfg.connection.publicKey}"
      '';

    # Write RustDesk2.toml for a given user.
    # Uses an unquoted heredoc so the shell expands $RUSTDESK_KEY inline.
    # The [peers] section and this machine's fixed ID are baked in at eval time.
    # Always overwrites so changes propagate on every rebuild.
    writeConfigForUser = user: homeDir: ''
      CONFIG_DIR="${homeDir}/.config/rustdesk"
      mkdir -p "$CONFIG_DIR"
      cat > "$CONFIG_DIR/RustDesk2.toml" << RDEOF
      id = '${thisId}'
      rendezvous_server = '${cfg.connection.idServer}'
      nat_type = 1
      serial = 0

      [options]
      custom-rendezvous-server = '${cfg.connection.idServer}'
      relay-server = '${cfg.connection.relayServer}'
      api-server = ' '
      key = '$RUSTDESK_KEY'
      direct-server = 'Y'
      direct-access-port = '21118'

      ${renderPeersSection}
      RDEOF
      chown -R "${user}:" "$CONFIG_DIR"
      chmod 600 "$CONFIG_DIR/RustDesk2.toml"
      echo "rustdesk-nixlab: wrote config for ${user} (id=${thisId})"
    '';
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

        # OPTIONAL: Where hbbs stores its keypair and relay state
        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/rustdesk";
          description = "Directory for RustDesk server data (keys, relay state)";
        };

        # ----------------------------------------------------------------------------
        # CONNECTION - Shared server details used by both remote and client roles.
        # Only needs to be set once per machine.
        # ----------------------------------------------------------------------------
        connection = {
          idServer = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            example = "192.168.1.10";
            description = ''
              IP or domain of the hbbs ID/rendezvous server.
              Defaults to localhost for all-in-one deployments.
            '';
          };

          relayServer = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            example = "192.168.1.10";
            description = ''
              IP or domain of the hbbr relay server.
              Defaults to localhost for all-in-one deployments.
            '';
          };

          autoKey = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Automatically read the server public key from dataDir at activation
              time and inject it into all client configs on this machine.

              This works out of the box when hbbs runs on the same machine.
              For client-only machines pointed at a remote server, set this to
              false and supply publicKey manually instead.

              On first boot (before hbbs has generated its keypair), the config
              is written without a key and rustdesk-keypopulate.service will
              patch it in as soon as the key file appears.
            '';
          };

          publicKey = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "abc123...";
            description = ''
              Public key from the server (contents of /var/lib/rustdesk/id_ed25519.pub).
              Only used when autoKey = false.
              Leave empty to allow unauthenticated connections (not recommended
              for internet-facing deployments).
            '';
          };
        };

        # ----------------------------------------------------------------------------
        # HBBS - Rendezvous / ID server
        # ----------------------------------------------------------------------------
        hbbs = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable the hbbs rendezvous/ID server on this machine";
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
            default = false;
            description = "Enable the hbbr relay server on this machine";
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
        # Runs rustdesk --service as a persistent systemd user service so the
        # machine is reachable even without an active interactive session.
        # loginctl enable-linger is set automatically so it survives reboots.
        # Requires a graphical session (X11 or Wayland) to share.
        # ----------------------------------------------------------------------------
        remote = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Enable always-on remote access so this machine can be connected to.
              Runs the RustDesk daemon as a persistent systemd user service.
            '';
          };

          user = lib.mkOption {
            type = lib.types.str;
            default = config.nixlab.mainUser;
            description = "The user whose desktop session will be shared";
          };

          autostart = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Automatically start the remote daemon on login / at boot";
          };
        };

        # ----------------------------------------------------------------------------
        # CLIENT - Workstation side (this machine connects TO others)
        #
        # Installs the RustDesk GUI app and pre-populates each user's config so
        # the app is pointed at your server immediately after deploy.
        # ----------------------------------------------------------------------------
        client = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Install and pre-configure the RustDesk GUI client so this machine
              can connect to other machines. Config is written on every activation
              so server/key changes propagate automatically.
            '';
          };

          users = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [config.nixlab.mainUser];
            description = "Users to pre-configure the RustDesk client for";
          };
        };

        # ----------------------------------------------------------------------------
        # PEERS - Fleet manifest for declarative peer discovery
        #
        # List all machines in your fleet here. Each machine's RustDesk ID is
        # derived deterministically from its hostname using a hash, so IDs are
        # stable and known at build time without any manual lookup.
        #
        # Every machine gets this list written into its RustDesk config, filtered
        # to exclude itself. The result is that every machine in your fleet
        # appears pre-populated in every other machine's address book.
        #
        # Define this list once in a shared nixlab module imported by all machines.
        # ----------------------------------------------------------------------------
        peers = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              hostname = lib.mkOption {
                type = lib.types.str;
                example = "nixsun";
                description = ''
                  The NixOS hostname of the peer (config.networking.hostName).
                  Used to derive a stable RustDesk ID via hostname hash.
                '';
              };
              alias = lib.mkOption {
                type = lib.types.str;
                example = "Living Room PC";
                description = ''
                  Human-readable display name shown in the RustDesk address book.
                  Defaults to the hostname if not set.
                '';
              };
            };
          });
          default = [];
          example = lib.literalExpression ''
            [
              { hostname = "nixsun";  alias = "Living Room";  }
              { hostname = "nixace";  alias = "Office Desk";  }
              { hostname = "nixvat";  alias = "Server Rack";  }
            ]
          '';
          description = ''
            Fleet manifest. Each entry becomes a pre-populated address book entry
            in RustDesk on every machine. IDs are derived from hostnames so no
            manual ID lookup is ever needed.
          '';
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
      # --------------------------------------------------------------------------
      # SERVER: Dedicated system user + data directory
      # --------------------------------------------------------------------------
      users.users.rustdesk = lib.mkIf (cfg.hbbs.enable || cfg.hbbr.enable) {
        isSystemUser = true;
        group = "rustdesk";
        home = cfg.dataDir;
        createHome = true;
        description = "RustDesk server daemon user";
      };

      users.groups.rustdesk = lib.mkIf (cfg.hbbs.enable || cfg.hbbr.enable) {};

      users.users.${config.nixlab.mainUser}.extraGroups =
        lib.mkIf (cfg.hbbs.enable || cfg.hbbr.enable) ["rustdesk"];

      system.activationScripts.initRustdeskDir = lib.mkIf (cfg.hbbs.enable || cfg.hbbr.enable) {
        text = ''
          mkdir -p "${cfg.dataDir}"
          chown -R rustdesk:rustdesk "${cfg.dataDir}"
          chmod 750 "${cfg.dataDir}"
        '';
      };

      # --------------------------------------------------------------------------
      # SERVER: hbbs
      # --------------------------------------------------------------------------
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

      # --------------------------------------------------------------------------
      # SERVER: hbbr
      # --------------------------------------------------------------------------
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

      # --------------------------------------------------------------------------
      # KEY POPULATE SERVICE
      #
      # On first boot hbbs hasn't run yet, so id_ed25519.pub doesn't exist when
      # the activation script runs. This one-shot systemd service fires after
      # hbbs starts (which generates the keypair), then re-writes every client
      # config with the real key. It is a no-op on subsequent boots once the
      # key file is stable.
      # --------------------------------------------------------------------------
      systemd.services.rustdesk-keypopulate = lib.mkIf (cfg.connection.autoKey && cfg.hbbs.enable) {
        description = "Populate RustDesk client configs with server public key";
        wantedBy = ["multi-user.target"];

        # Run after hbbs so the keypair exists
        after = ["rustdesk-hbbs.service"];
        requires = ["rustdesk-hbbs.service"];

        # Re-run on every boot so key rotations propagate automatically
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          KEY_FILE="${cfg.dataDir}/id_ed25519.pub"

          # Wait up to 30s for hbbs to generate the keypair
          TRIES=0
          while [ ! -f "$KEY_FILE" ] && [ $TRIES -lt 30 ]; do
            sleep 1
            TRIES=$((TRIES + 1))
          done

          if [ ! -f "$KEY_FILE" ]; then
            echo "rustdesk-keypopulate: timed out waiting for $KEY_FILE"
            exit 1
          fi

          RUSTDESK_KEY="$(cat "$KEY_FILE")"

          ${lib.optionalString cfg.remote.enable
            (writeConfigForUser cfg.remote.user "/home/${cfg.remote.user}")}

          ${lib.concatMapStrings
            (user: writeConfigForUser user "/home/${user}")
            (lib.optionals cfg.client.enable cfg.client.users)}

          echo "rustdesk-keypopulate: all configs updated with key"
        '';
      };

      # --------------------------------------------------------------------------
      # CLIENT + REMOTE: Install the GUI package
      # --------------------------------------------------------------------------
      environment.systemPackages =
        lib.optionals (cfg.remote.enable || cfg.client.enable) [cfg.clientPackage];

      # --------------------------------------------------------------------------
      # ACTIVATION: Write client configs
      #
      # Runs on every nixos-rebuild so server address or key changes propagate.
      # resolveKeyScript sets $RUSTDESK_KEY — either from the key file (autoKey)
      # or from the publicKey option value.
      # --------------------------------------------------------------------------
      system.activationScripts.rustdeskWriteConfigs = lib.mkIf (cfg.remote.enable || cfg.client.enable) {
        # Must run after the server data dir is initialised (if server is local)
        deps = lib.optionals (cfg.hbbs.enable || cfg.hbbr.enable) ["initRustdeskDir"];

        text = ''
          ${resolveKeyScript}

          ${lib.optionalString cfg.remote.enable
            (writeConfigForUser cfg.remote.user "/home/${cfg.remote.user}")}

          ${lib.concatMapStrings
            (user: writeConfigForUser user "/home/${user}")
            (lib.optionals cfg.client.enable cfg.client.users)}
        '';
      };

      # --------------------------------------------------------------------------
      # REMOTE: Enable linger + systemd user service
      # --------------------------------------------------------------------------
      system.activationScripts.rustdeskRemoteLinger = lib.mkIf cfg.remote.enable {
        text = ''
          ${pkgs.systemd}/bin/loginctl enable-linger ${cfg.remote.user}
        '';
      };

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

      # --------------------------------------------------------------------------
      # NGINX REVERSE PROXY
      # --------------------------------------------------------------------------
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

      # --------------------------------------------------------------------------
      # FIREWALL
      #
      #   hbbs: 21115 (TCP)       - NAT type test
      #         21116 (TCP + UDP) - ID server + hole-punching
      #         21118 (TCP)       - Web client (optional)
      #   hbbr: 21117 (TCP)       - Relay
      #         21119 (TCP)       - Web client relay (optional)
      # --------------------------------------------------------------------------
      networking.firewall = lib.mkIf cfg.openFirewall {
        allowedTCPPorts =
          lib.optionals cfg.hbbs.enable [
            cfg.hbbs.port
            (cfg.hbbs.port + 1)
            (cfg.hbbs.port + 3)
          ]
          ++ lib.optionals cfg.hbbr.enable [
            cfg.hbbr.port
            (cfg.hbbr.port + 2)
          ]
          ++ lib.optionals (cfg.domain != null) [80 443];

        allowedUDPPorts = lib.optionals cfg.hbbs.enable [
          (cfg.hbbs.port + 1)
        ];
      };
    };
  };
}
/*
================================================================================
USAGE EXAMPLES
================================================================================

Typical fleet setup — define once in a shared nixlab module:
------------------------------------------------------------
# One file imported by every machine. Each machine gets the full peer list,
# filtered to exclude itself. IDs are derived from hostnames — no manual
# lookup ever needed.

services.rustdesk-nixlab = {
  enable = true;
  # remote.enable = true (default) — every machine is connectable
  # client.enable = true (default) — every machine can connect to others

  connection = {
    idServer    = "192.168.1.10";   # your dedicated hbbs machine
    relayServer = "192.168.1.10";
    autoKey     = false;
    publicKey   = "your-key-here"; # cat /var/lib/rustdesk/id_ed25519.pub
  };

  peers = [
    { hostname = "nixsun";  alias = "Living Room";  }
    { hostname = "nixace";  alias = "Office Desk";  }
    { hostname = "nixvat";  alias = "Server Rack";  }
  ];
};

# Each machine's RustDesk ID is derived from its hostname, e.g.:
#   nixsun → hash → 483920174
#   nixace → hash → 729401853
#   nixvat → hash → 156738290
# These are stable and consistent across all machines in the fleet.


Dedicated server machine (hbbs + hbbr, also part of the fleet):
----------------------------------------------------------------
services.rustdesk-nixlab = {
  enable = true;

  hbbs.enable = true;
  hbbr.enable = true;

  # autoKey = true (default) — reads key from dataDir automatically.
  # On first boot rustdesk-keypopulate.service patches it in after hbbs runs.
  connection = {
    idServer    = "localhost";
    relayServer = "localhost";
  };

  peers = [
    { hostname = "nixsun";  alias = "Living Room";  }
    { hostname = "nixace";  alias = "Office Desk";  }
  ];
};


All-in-one single machine (server + client + remote + peers):
-------------------------------------------------------------
services.rustdesk-nixlab = {
  enable       = true;
  openFirewall = true;

  hbbs.enable = true;
  hbbr.enable = true;

  connection = {
    idServer    = "localhost";
    relayServer = "localhost";
    # autoKey = true (default) — no publicKey needed, ever
  };

  peers = [
    { hostname = "nixsun"; alias = "Living Room"; }
    { hostname = "nixace"; alias = "Office Desk"; }
  ];
};


Remote-only (headless server, no GUI client):
--------------------------------------------
services.rustdesk-nixlab = {
  enable        = true;
  client.enable = false;

  connection = {
    idServer    = "192.168.1.10";
    relayServer = "192.168.1.10";
    autoKey     = false;
    publicKey   = "your-key-here";
  };
  # No peers needed — headless machines don't use the address book
};
*/

