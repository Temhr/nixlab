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
  };
}
