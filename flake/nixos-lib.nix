# Shared helper functions available to all NixOS modules via specialArgs.
# Receive in any module with: { nixlabLib, ... }:
# Then destructure: inherit (nixlabLib) mkNginxVirtualHost mkFirewallPorts mkServiceHardening mkSslAssertion;
{lib, ...}: {
  flake.lib.nixlabLib = {
    # ---------------------------------------------------------------------------
    # mkNginxVirtualHost
    # Returns an attrset for services.nginx.virtualHosts.
    # Returns empty attrset when domain is null (no proxy configured).
    #
    # Usage:
    #   services.nginx.virtualHosts = nixlabLib.mkNginxVirtualHost {
    #     inherit (cfg) domain listenAddress port enableSSL;
    #     # extraConfig is appended after the standard proxy headers.
    #     # Use it for service-specific settings like WebSocket support.
    #     extraConfig = ''
    #       proxy_http_version 1.1;
    #       proxy_set_header Upgrade $http_upgrade;
    #       proxy_set_header Connection "upgrade";
    #     '';
    #   };
    # ---------------------------------------------------------------------------
    mkNginxVirtualHost = {
      domain,
      listenAddress,
      port,
      enableSSL,
      extraConfig ? "",
      proxyWebsockets ? true,
    }:
      lib.optionalAttrs (domain != null) {
        ${domain} = {
          forceSSL = enableSSL;
          enableACME = enableSSL;
          locations."/" = {
            proxyPass = "http://${listenAddress}:${toString port}";
            inherit proxyWebsockets;
            extraConfig =
              ''
                proxy_set_header Host              $host;
                proxy_set_header X-Real-IP         $remote_addr;
                proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              ''
              + extraConfig;
          };
        };
      };

    # ---------------------------------------------------------------------------
    # mkFirewallPorts
    # Returns a list for networking.firewall.allowedTCPPorts.
    # When domain is set: opens 80 + 443 for nginx.
    # When no domain: opens servicePort only if listenAddress is not loopback.
    # Pass extraPorts for additional ports (e.g. gRPC, sync ports).
    #
    # Usage:
    #   networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall
    #     (nixlabLib.mkFirewallPorts {
    #       inherit (cfg) domain listenAddress;
    #       servicePort = cfg.port;
    #       extraPorts  = [ cfg.grpcPort ];   # optional
    #     });
    # ---------------------------------------------------------------------------
    mkFirewallPorts = {
      domain,
      listenAddress,
      servicePort,
      extraPorts ? [],
    }:
      lib.optionals (domain == null && listenAddress != "127.0.0.1") [servicePort]
      ++ lib.optionals (domain != null) [80 443]
      ++ extraPorts;

    # ---------------------------------------------------------------------------
    # mkServiceHardening
    # Returns a systemd serviceConfig attrset with standard hardening options.
    # Merge it into serviceConfig with //, then add service-specific options.
    # Service-specific options written after // will override these if needed.
    #
    # Options:
    #   writablePaths  — list of paths the service needs read-write access to
    #   allowNetwork   — set false for services that need no network access
    #   allowDevices   — set true for services needing /dev access (e.g. GPU)
    #   allowJIT       — set true for JIT-compiled runtimes (Next.js, Node.js,
    #                    eBPF-based tools) that need write+execute memory and
    #                    syscalls outside @system-service. Relaxes
    #                    MemoryDenyWriteExecute and SystemCallFilter.
    #
    # Usage:
    #   serviceConfig = nixlabLib.mkServiceHardening {
    #     writablePaths = [ cfg.dataDir ];
    #     allowJIT = true;
    #   } // {
    #     Type      = "simple";
    #     User      = cfg.user;
    #     ExecStart = "...";
    #   };
    # ---------------------------------------------------------------------------
    mkServiceHardening = {
      writablePaths ? [],
      allowNetwork ? true,
      allowDevices ? false,
      allowJIT ? false,
    }:
      {
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        MemoryDenyWriteExecute = true;
        SystemCallFilter = "@system-service";
        ReadWritePaths = writablePaths;
      }
      // lib.optionalAttrs allowNetwork {
        RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
      }
      // lib.optionalAttrs (!allowDevices) {
        PrivateDevices = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictNamespaces = true;
        ProtectControlGroups = true;
        LockPersonality = true;
      }
      // lib.optionalAttrs allowJIT {
        MemoryDenyWriteExecute = false;
        SystemCallFilter = "";
      };

    # ---------------------------------------------------------------------------
    # mkSslAssertion
    # Returns a NixOS assertion attrset.
    # Include in a module's assertions list.
    #
    # Usage:
    #   assertions = [
    #     (nixlabLib.mkSslAssertion {
    #       inherit (cfg) enableSSL domain;
    #       moduleName = "services.my-service";
    #     })
    #   ];
    # ---------------------------------------------------------------------------
    mkSslAssertion = {
      enableSSL,
      domain,
      moduleName,
    }: {
      assertion = !enableSSL || domain != null;
      message = "${moduleName}: enableSSL = true requires domain to be set.";
    };
    # ---------------------------------------------------------------------------
    # mkDataDirPermissionsService
    # Returns a systemd.services.<name> body (a oneshot unit) that recursively
    # chowns dataDir to user:group on every boot, AFTER dataDir's filesystem is
    # actually mounted.
    #
    # Fixes two related problems:
    #   1. UID/GID drift — if the service's system user gets reallocated a new
    #      UID/GID across a nixos-rebuild, files on disk stay stamped with the
    #      old numeric ID and become inaccessible.
    #   2. tmpfiles.rules "d"/"Z" ordering — systemd-tmpfiles-setup.service runs
    #      before local-fs.target, so tmpfiles rules targeting a path on a
    #      separate mount (e.g. /data) can run before that mount exists and
    #      silently no-op. RequiresMountsFor sidesteps this by waiting on the
    #      actual mount unit.
    #
    # Runs as root (no User=) so it can always fix ownership regardless of what
    # currently owns the files.
    #
    # Usage:
    #   systemd.services.comfyui-permissions = nixlabLib.mkDataDirPermissionsService {
    #     inherit pkgs;
    #     dataDir = cfg.dataDir;
    #     user    = cfg.user;
    #     group   = cfg.group;
    #   };
    #
    #   # then wire it into your existing chain:
    #   systemd.services.comfyui-patch.requires = ["comfyui-permissions.service"];
    #   systemd.services.comfyui-patch.after    = ["comfyui-permissions.service"];
    #   # ...repeat for comfyui-pytorch-setup and comfyui, or use requiredBy below.
    # ---------------------------------------------------------------------------
    mkDataDirPermissionsService = {
      pkgs,
      dataDir,
      user,
      group,
      requiredBy ? [],
    }: {
      description = "Ensure ${dataDir} ownership matches ${user}:${group}";
      unitConfig.RequiresMountsFor = [dataDir];
      inherit requiredBy;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/chown -R ${user}:${group} ${dataDir}";
      };
    };

    # ---------------------------------------------------------------------------
    # mkWalSelfHeal
    # Returns a NixOS config fragment (merge it into the service module's config
    # with lib.mkMerge) that recovers a service whose write-ahead log is corrupt.
    #
    # How it works:
    #   1. The service gets a start limit (3 failed starts in 5 minutes). When
    #      it trips, systemd marks the unit failed and fires OnFailure.
    #   2. <unit>-wal-recover.service runs as root. It only acts if the unit's
    #      recent journal matches errorPattern, so unrelated failures never get
    #      data moved around.
    #   3. It moves walDir aside as walDir.broken-<timestamp>, recreates an empty
    #      walDir with the right ownership, resets the failed state and starts
    #      the unit again.
    #   4. At most `keep` quarantined copies are retained, and recovery runs at
    #      most once per cooldownSeconds, so a persistent fault (full disk, bad
    #      hardware) cannot loop forever and eat data.
    #
    # Cost: whatever was only in the WAL (the last few minutes of data) is lost.
    # This is a safety net, not a repair. If it fires often, find the cause.
    #
    # Usage (in a service module):
    #   config = lib.mkIf cfg.enable (lib.mkMerge [
    #     { ...existing config... }
    #     (nixlabLib.mkWalSelfHeal {
    #       inherit pkgs;
    #       unit  = "loki";
    #       walDir = "${cfg.dataDir}/wal";
    #       user  = cfg.user;
    #       group = cfg.group;
    #     })
    #   ]);
    # ---------------------------------------------------------------------------
    mkWalSelfHeal = {
      pkgs,
      unit,
      walDir,
      user,
      group,
      # Extended regex, matched case-insensitively against the unit's journal.
      errorPattern ? "segments are not sequential|wal.*corrupt|corrupt.*wal|checkpoint.*corrupt",
      keep ? 2,
      cooldownSeconds ? 3600,
    }: let
      recoverUnit = "${unit}-wal-recover";
      script = pkgs.writeShellScript recoverUnit ''
        set -eu
        export PATH=${lib.makeBinPath [pkgs.coreutils pkgs.gnugrep pkgs.systemd]}

        stamp=/var/lib/${recoverUnit}/last-recovery
        now=$(date +%s)

        if [ -f "$stamp" ]; then
          last=$(cat "$stamp")
          if [ $((now - last)) -lt ${toString cooldownSeconds} ]; then
            echo "${recoverUnit}: last recovery was under ${toString cooldownSeconds}s ago, not recovering again"
            exit 0
          fi
        fi

        if ! journalctl -u ${unit}.service --since "-15min" --no-pager -o cat \
            | grep -qiE ${lib.escapeShellArg errorPattern}; then
          echo "${recoverUnit}: no WAL error in recent ${unit} logs, leaving data alone"
          exit 0
        fi

        if [ ! -d ${lib.escapeShellArg walDir} ]; then
          echo "${recoverUnit}: ${walDir} does not exist, nothing to move"
          exit 0
        fi

        dest=${lib.escapeShellArg walDir}.broken-$(date +%Y%m%d-%H%M%S)
        echo "${recoverUnit}: moving ${walDir} to $dest"
        mv ${lib.escapeShellArg walDir} "$dest"
        install -d -m 0770 -o ${user} -g ${group} ${lib.escapeShellArg walDir}
        echo "$now" > "$stamp"

        # Keep only the newest ${toString keep} quarantined copies.
        ls -1d ${lib.escapeShellArg walDir}.broken-* 2>/dev/null | sort | head -n -${toString keep} | xargs -r rm -rf || true

        systemctl reset-failed ${unit}.service
        systemctl start ${unit}.service
      '';
    in {
      systemd.services.${unit}.unitConfig = {
        StartLimitIntervalSec = 300;
        StartLimitBurst = 3;
        OnFailure = ["${recoverUnit}.service"];
      };

      systemd.services.${recoverUnit} = {
        description = "Recover ${unit} from a corrupt write-ahead log";
        serviceConfig = {
          Type = "oneshot";
          StateDirectory = recoverUnit;
          ExecStart = script;
        };
      };
    };
  };
}
