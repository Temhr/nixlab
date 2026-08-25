# Nixlab Service Module Template & Style Guide

Derived by reverse-engineering every module in your repo (glance, zola, loki,
alertmanager, grafana, prometheus, ntfy, ollama, syncthing, waydroid,
node-red, matrix, home-assistant, wiki-js, homepage-dashboard, hermes,
bookstack, comfyui, cachix), plus the `nsops--*` secrets-joiner modules in
`/nixlab/sops/`, and the shared `nixlabLib` helper library and flake-parts
plumbing (`builders/`, `schema/`, `data/`) that the service modules depend
on. The pattern is extremely consistent — this is the shared skeleton
distilled out, so you (or Claude) can stamp out a new module in the house
style without re-deriving it each time.

A service almost always ships as **two files**: the `servc--*` module
(§3–§6) plus a companion `nsops--*` module (§12) that wires sops-nix secrets
into it. Treat them as a pair — when Claude drafts a new service, ask it for
both.

---

## 1. File layout

```
/nixlab/modules/ports.nix                     # central port manifest (see §7)
/nixlab/modules/nixos/<service>.nix           # single-file service
/nixlab/modules/nixos/<service>/default.nix   # multi-file service (complex)
/nixlab/modules/nixos/<service>/_helper.nix   # private helpers, underscore-prefixed,
                                               #   not exposed as a flake module
/nixlab/sops/<service>.nix                    # sops secrets joiner for <service> (see §12)
/nixlab/sops/<service>.yaml                   # the sops-encrypted secrets file itself,
                                               #   co-located with its joiner module
/nixlab/flake/nixos-lib.nix                   # nixlabLib — shared helpers (see §8)
/nixlab/flake/builders/*.nix                  # mkHost / mkHomeUser / hardware-profile builders
/nixlab/flake/schema/*.nix                    # lib.evalModules-backed schemas for hosts/hardware meta
/nixlab/flake/data/*.nix                      # the actual hosts/users/hardware metadata tables
```

Rule of thumb: single `.nix` file until the module needs a private data file
(e.g. `glance/_glance-pages.nix`, `homepage-dashboard/_services.nix`) or is
naturally split into sub-concerns (e.g. `monitoring/prometheus/_internals/*`
splits config/exporters/alerts/scrape-configs). Then promote it to a
directory with `default.nix` as the entry point.

The `builders/`, `schema/`, and `data/` files aren't part of the service
module pattern itself — they're the flake-parts machinery that turns
`hostsMeta`/`usersMeta`/`hardwareMeta` tables into actual `nixosSystem`
calls (`mkHost`), NixOS user accounts (`mkSystemUser`), and home-manager
profiles (`mkHomeUser`). You won't touch these when adding a new service;
they're included here only so Claude has the full picture of how a service
module's `config.nixlab.mainUser` and `allHosts` module args actually get
populated.

## 2. Naming convention

| Thing | Pattern | Example |
|---|---|---|
| Flake module attr (the service itself) | `flake.nixosModules.servc--<service>-nixlab` (or `-custom`) | `servc--zola-nixlab` |
| Flake module attr (port-only module) | `flake.nixosModules.systm--ports-<service>` | `systm--ports-zola` |
| Flake module attr (misc system-level module) | `flake.nixosModules.systm--<name>` | `systm--cachix` |
| Flake module attr (sops secrets joiner) | `flake.nixosModules.nsops--<service>` | `nsops--zola` |
| NixOS option namespace | `services.<service>-nixlab` (matches the flake attr suffix) | `services.zola-nixlab` |
| systemd unit | `systemd.services.<short-name>` (no `-nixlab` suffix, human-friendly) | `systemd.services.zola` |
| dedicated system user/group | same as the systemd unit name | `zola` / `zola` |

The `-nixlab` / `-custom` suffix on the option namespace exists so it never
collides with an upstream `services.<name>` option shipped by nixpkgs
(several of these services — home-assistant, wiki-js, ollama — have their own
upstream module, and this repo deliberately shadows/replaces it rather than
extending it).

`servc--` = a real service module. `systm--` = system-level plumbing (ports
manifest entries, cachix config, etc.) — not something you `enable`. `nsops--`
= a secrets-joining module: it imports the matching `servc--*` module and
wires sops-nix-decrypted secrets into that module's own options (see §12).
The naming of the module attr itself drops the `-nixlab`/`-custom` suffix
(`nsops--zola`, not `nsops--zola-nixlab`) — it joins to
`services.zola-nixlab`, but the *module attr* just needs to be unique, and
the shorter form is what every example uses.

## 3. Top-level module skeleton

Every service module is one function from the flake-parts `self`/module args
to an attrset containing exactly one `flake.nixosModules.servc--*` entry.
Copy this shape verbatim:

```nix
# /nixlab/modules/nixos/<service>.nix
{self, ...}: {
  flake.nixosModules.servc--<service>-nixlab = {
    config,
    lib,
    pkgs,
    nixlabLib,
    ...
  }: let
    cfg = config.services.<service>-nixlab;

    # any derived/computed values go here (see §6)
  in {
    imports = [
      self.nixosModules.systm--ports-<service>
    ];

    options = {
      services.<service>-nixlab = {
        # see §4
      };
    };

    config = lib.mkIf cfg.enable {
      # see §5
    };
  };
}
```

Notes:
- `{self, ...}:` at the very top is only needed if the module imports another
  flake module (almost always true, for the ports module). Drop it if there's
  nothing to import.
- Only pull in the module args you actually use. `allHosts` appears only in
  glance (needs the host list to build dashboard pages). Most modules just
  need `config, lib, pkgs, nixlabLib, ...`.
- `cfg` is always bound once, right after the arg list, before `in`.

## 4. `options` section conventions

Options are declared in a **fixed, near-universal order**. Every option gets
a `# REQUIRED:` or `# OPTIONAL: ... (default: X)` comment line directly above
it — this is not optional, every module does it. Keep using it; it's what
makes the module self-documenting from `:g/OPTIONAL/` alone.

```nix
services.<service>-nixlab = {
  # REQUIRED: Enable the service
  enable = lib.mkEnableOption "<Human-readable service description>";

  # OPTIONAL: Port to listen on (default: <port>)
  port = lib.mkOption {
    type = lib.types.port;
    default = <port>;               # matches the systm--ports-<service> value
    description = "Port for <Service> to listen on";
  };

  # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
  listenAddress = lib.mkOption {
    type = lib.types.str;
    default = "127.0.0.1";
    description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
  };

  # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
  domain = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "service.example.com";
    description = "Domain name for nginx reverse proxy (optional)";
  };

  # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
  enableSSL = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable HTTPS with Let's Encrypt (requires domain)";
  };

  # OPTIONAL: Where to store service data (default: /var/lib/<service>)
  dataDir = lib.mkOption {
    type = lib.types.path;
    default = "/var/lib/<service>";
    example = "/data/<service>";
    description = "Directory for <Service> data";
  };

  # OPTIONAL: Package to use (default: pkgs.<pkg>)
  package = lib.mkOption {
    type = lib.types.package;
    default = pkgs.<pkg>;
    defaultText = lib.literalExpression "pkgs.<pkg>";
    description = "The <Service> package to use";
  };

  user = lib.mkOption {
    type = lib.types.str;
    default = "<service>";
    description = "User to run <Service> as";
  };

  group = lib.mkOption {
    type = lib.types.str;
    default = "<service>";
    description = "Group to run <Service> as";
  };

  # OPTIONAL: allow opting out of the mainUser group membership
  # without coupling to a specific external option name
  extraUsers = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["alice"];
    description = "Extra users to add to the group";
  };

  # OPTIONAL: Auto-open firewall ports (default: true)
  openFirewall = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Open firewall ports";
  };

  # OPTIONAL: sops-nix path to a KEY=value env file for secrets.
  secretsEnvFile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    example = "/run/secrets/<SERVICE>_ENV";
    description = ''
      Path to a sops-decrypted KEY=value env file injected into the
      service environment. When null, no extra environment variables
      are injected.
    '';
  };
};
```

Everything below `secretsEnvFile` is **service-specific** — add whatever the
service actually needs (e.g. `siteDir`/`configToml` for zola,
`downloadSD15`/`customModels` for comfyui-models). Keep the same
`# REQUIRED:` / `# OPTIONAL: (default: X)` comment discipline for those too.

Not every module needs every option above — `waydroid` (no HTTP surface) skips
`port`/`listenAddress`/`domain`/`enableSSL`/`openFirewall`/`secretsEnvFile`
entirely and just keeps `enable`, `package`, `dataDir`-style options plus its
own domain-specific ones (`useNftables`, `allowedUsers`, `autoStart`,
`enableGapps`). **Only include the web-server-shaped options if the service
actually listens on a port.**

### 4a. Secrets sink options — the servc↔nsops contract

`secretsEnvFile` above is the *simple* case: one KEY=value env file, wired
straight to `EnvironmentFile`. But it's really one instance of a broader
pattern: **the `servc--*` module always declares a `nullOr path` "sink"
option for anything secret, and only the companion `nsops--*` module (§12)
ever sets it.** A host config never sets these directly — it just enables
sops and lets the joiner module populate them. You'll see this same shape
under different names depending on what the secret actually *is*:

| Option name (seen in repo) | Shape of the secret | Consumed as |
|---|---|---|
| `secretsEnvFile` | KEY=value env file | `serviceConfig.EnvironmentFile` |
| `environmentFile` | KEY=value env file | `serviceConfig.EnvironmentFile` (alertmanager, homepage) |
| `webuiSecretKeyFile` | single opaque token | read into a specific setting/env var |
| `appSecretFile` | single opaque token | read into a specific setting/env var |
| `secretsYamlFile` | a whole YAML file installed verbatim | copied into `dataDir` at activation/preStart |
| `credentialsEnvFile` | composed env file (built via `sops.templates`, not a raw secret) | `serviceConfig.EnvironmentFile` |
| `registrationTokenFile` | single opaque token | passed to a service-specific option that itself expects a file path |

When you design a new module's options, ask "what shape is this service's
secret?" and pick (or invent) the matching `nullOr path` sink option name —
don't force everything into `secretsEnvFile` if the service actually wants a
whole file installed (like Zola's `config.toml` pattern, or Home Assistant's
`secrets.yaml`). Always: `type = lib.types.nullOr lib.types.path; default =
null;` — never a default guess at a real path, since a real value only ever
comes from the paired `nsops--*` module.

## 5. `config` section conventions

`config = lib.mkIf cfg.enable { ... }` is always a single block, broken into
clearly banner-commented sections, always in this order when applicable:

```nix
config = lib.mkIf cfg.enable {
  # ============================================================================
  # ASSERTIONS - Catch invalid option combinations at eval time
  # ============================================================================
  assertions = [
    (nixlabLib.mkSslAssertion {
      inherit (cfg) enableSSL domain;
      moduleName = "services.<service>-nixlab";
    })
  ];

  # ----------------------------------------------------------------------------
  # DIRECTORY SETUP - Create necessary directories with proper permissions
  # ----------------------------------------------------------------------------
  systemd.tmpfiles.rules = [
    "d ${cfg.dataDir} 0770 ${cfg.user} ${cfg.group} -"
  ];

  # ----------------------------------------------------------------------------
  # USER SETUP - Dedicated system user/group for the service
  # ----------------------------------------------------------------------------
  users.groups.${cfg.group} = {};

  users.users = lib.mkMerge (
    [
      {
        ${cfg.user} = {
          isSystemUser = true;
          group = cfg.group;
          home = cfg.dataDir;
          description = "<Service> service user";
        };
      }
    ]
    ++ lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
    (map (u: {${u} = {extraGroups = [cfg.group];};})
      ([config.nixlab.mainUser] ++ cfg.extraUsers))
  );

  # ----------------------------------------------------------------------------
  # <SERVICE> SERVICE - systemd unit
  # ----------------------------------------------------------------------------
  systemd.services.<service> = {
    description = "<Human-readable description>";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];

    serviceConfig =
      nixlabLib.mkServiceHardening {
        writablePaths = [cfg.dataDir];
      }
      // {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/<binary> --port ${toString cfg.port} ...";
        Restart = "on-failure";
        RestartSec = "10s";
      }
      // lib.optionalAttrs (cfg.secretsEnvFile != null) {
        EnvironmentFile = cfg.secretsEnvFile;
      };
  };

  # ----------------------------------------------------------------------------
  # NGINX REVERSE PROXY - Only configured if domain is set
  # ----------------------------------------------------------------------------
  services.nginx.enable = lib.mkIf (cfg.domain != null) true;

  services.nginx.virtualHosts = nixlabLib.mkNginxVirtualHost {
    inherit (cfg) domain listenAddress port enableSSL;
    extraConfig = ''
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
    '';
  };

  # ----------------------------------------------------------------------------
  # FIREWALL - Open necessary ports when requested
  # ----------------------------------------------------------------------------
  networking.firewall.allowedTCPPorts =
    lib.mkIf cfg.openFirewall
    (nixlabLib.mkFirewallPorts {
      inherit (cfg) domain listenAddress;
      servicePort = cfg.port;
    });
};
```

Two comment-banner styles are used and both are fine, pick by weight:
- `# === HEADER ===` (double-line, `=`) for top-level sections (OPTIONS,
  ASSERTIONS, CONFIG).
- `# --- header ---` (single-line, `-`) for sub-sections within `config`
  (DIRECTORY SETUP, USER SETUP, the service block, NGINX, FIREWALL).

Non-web services (waydroid-style) drop the NGINX and FIREWALL blocks
entirely and replace the systemd-service block with whatever the service
actually needs (kernel modules/params, activation scripts, etc.), but keep
the OPTIONS → ASSERTIONS → directories → users → main-config ordering.

## 6. `let ... in` computed-values conventions

Anything derived from `cfg` that's used more than once, or that needs
explaining, gets pulled into a named `let` binding above the module body,
with a comment explaining the precedence/derivation logic — see zola's
`effectiveBaseUrl` and `configFile` for the canonical example:

```nix
let
  cfg = config.services.zola-nixlab;

  # Compute the effective base URL used for --base-url flag and config.toml
  # generation. Priority: explicit baseUrl option > domain (with scheme) >
  # listenAddress:port fallback.
  effectiveBaseUrl =
    if cfg.baseUrl != null
    then cfg.baseUrl
    else if cfg.domain != null
    then "${if cfg.enableSSL then "https" else "http"}://${cfg.domain}"
    else "http://${cfg.listenAddress}:${toString cfg.port}";
in ...
```

Rule: if you're about to write the same `if cfg.domain != null then ... else
...` expression twice, hoist it into a named `let` binding with a doc
comment above it instead.

## 7. `ports.nix` — the central port manifest

Every service that listens on a network port gets **two things**:

1. An entry in `services.<service>-nixlab.port` with `default = N` inside its
   own module (the "safety net" — lowest priority).
2. A dedicated `systm--ports-<service>` module in `ports.nix` that sets the
   same value with `lib.mkDefault N` (the fleet-wide default — imported by
   the service module itself, see §3's `imports`).

Precedence, highest to lowest (this exact block is copy-pasted verbatim at
the top of `ports.nix` — keep it there):

```nix
# Port precedence (highest to lowest):
#   1. Host config files (hosts/<name>.nix) — plain assignment, e.g.
#        services.<service>-nixlab.port = 3005;
#      Always wins; do NOT use lib.mkDefault here or it will tie with
#      this file's own mkDefault and cause an eval error.
#   2. This file (ports.nix / ports-X modules) — lib.mkDefault, e.g.
#        services.<service>-nixlab.port = lib.mkDefault 3004;
#      The fleet-wide sensible default for hosts that don't override.
#   3. Each service module's own `options.services.X.port` default —
#      lowest priority, only takes effect if this file isn't imported
#      for that service at all (rare; a safety net, not meant to be
#      kept in sync with #2 by hand).
```

When you add a new service, append one block to `ports.nix`:

```nix
flake.nixosModules.systm--ports-<service> = {lib, ...}: {
  services.<service>-nixlab.port = lib.mkDefault <next-free-port>;
};
```

Pick a port that doesn't collide with the existing manifest (currently in
use: 1880, 2586, 3000–3007, 3100–3101, 6875, 8123, 8188, 8384, 9090, 9093,
9096, 9119, 11434 — check the live file before assigning a new one).

## 8. `nixlabLib` helpers used throughout

Defined in full at `/nixlab/flake/nixos-lib.nix`, exported as
`flake.lib.nixlabLib`, and threaded into **every** NixOS module's
`specialArgs` by `builders/hosts.nix` (`inherit nixlabLib;`) — that's why
every service module can just write `{config, lib, pkgs, nixlabLib, ...}:`
and have it available with no explicit import.

Confirmed exact signatures (previously inferred — now verified against the
source):

```nix
# ---------------------------------------------------------------------------
# mkNginxVirtualHost
# Returns an attrset for services.nginx.virtualHosts.
# Returns empty attrset when domain is null (no proxy configured).
# ---------------------------------------------------------------------------
mkNginxVirtualHost = {
  domain,
  listenAddress,
  port,
  enableSSL,
  extraConfig ? "",
  proxyWebsockets ? true,
}: ...

# ---------------------------------------------------------------------------
# mkFirewallPorts
# Returns a list for networking.firewall.allowedTCPPorts.
# domain set        -> [80 443]
# domain null, non-loopback listenAddress -> [servicePort]
# extraPorts always appended (e.g. gRPC, sync ports)
# ---------------------------------------------------------------------------
mkFirewallPorts = {
  domain,
  listenAddress,
  servicePort,
  extraPorts ? [],
}: ...

# ---------------------------------------------------------------------------
# mkServiceHardening
# Returns a systemd serviceConfig attrset with standard hardening.
# Merge with // then let unit-specific keys win.
# ---------------------------------------------------------------------------
mkServiceHardening = {
  writablePaths ? [],
  allowNetwork ? true,   # false -> no RestrictAddressFamilies grant
  allowDevices ? false,  # true  -> skip PrivateDevices/ProtectKernel*/etc.
  allowJIT ? false,      # true  -> relax MemoryDenyWriteExecute/SystemCallFilter
                         #   for JIT runtimes (Next.js, Node.js, eBPF tools)
}: ...

# ---------------------------------------------------------------------------
# mkSslAssertion
# Returns a NixOS assertion attrset: { assertion; message; }
# ---------------------------------------------------------------------------
mkSslAssertion = {
  enableSSL,
  domain,
  moduleName,
}: {
  assertion = !enableSSL || domain != null;
  message = "${moduleName}: enableSSL = true requires domain to be set.";
};
```

`mkServiceHardening`'s base return (before the optional attrs above) always
includes `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem = "strict"`,
`ProtectHome`, `MemoryDenyWriteExecute`, `SystemCallFilter =
"@system-service"`, and `ReadWritePaths = writablePaths`. `allowDevices =
false` (the default) additionally locks down `PrivateDevices`,
`ProtectKernelModules`, `ProtectKernelTunables`, `RestrictNamespaces`,
`ProtectControlGroups`, and `LockPersonality` — set `allowDevices = true`
for services needing `/dev` access (e.g. GPU passthrough, comfyui-p5000).

Only `writablePaths` is genuinely required in practice — every other
parameter has a sane default and can be omitted unless the service actually
needs it relaxed.

Always call `mkServiceHardening` first and `// { ... }` your unit-specific
`serviceConfig` on top of it — never write sandboxing flags by hand in a new
module.

## 9. Trailing doc-comment block

Every module file ends with a large `/* ... */` block (after the closing
`}` of the Nix expression) documenting it for humans. This isn't evaluated
by Nix — it's pure documentation, but every single module has it, so keep
doing it. Standard sections, in this order, include what's relevant:

```
/*
================================================================================
USAGE EXAMPLES
================================================================================

Minimal:
--------
services.<service>-nixlab = {
  enable = true;
};

Full configuration with nginx + SSL:
-------------------------------------
services.<service>-nixlab = {
  enable = true;
  domain = "service.example.com";
  enableSSL = true;
  openFirewall = true;
  extraUsers = ["alice"];
  secretsEnvFile = "/run/secrets/service-env";
};


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  systemctl status <service>

Stream live logs:
  journalctl -u <service> -f
*/
```

Longer/more complex modules (comfyui-models) also add MODEL SIZES,
PERFORMANCE TIPS, DISK SPACE, etc. — add whatever sections are actually
useful for that specific service; USAGE EXAMPLES + TROUBLESHOOTING are the
only two that are truly universal.

---

## 10. Fill-in-the-blank starter file

Copy this, replace every `<...>` placeholder, delete what doesn't apply
(non-web services: drop the port/nginx/firewall bits per §4–§5).

```nix
# /nixlab/modules/nixos/<service>.nix
{self, ...}: {
  flake.nixosModules.servc--<service>-nixlab = {
    config,
    lib,
    pkgs,
    nixlabLib,
    ...
  }: let
    cfg = config.services.<service>-nixlab;
  in {
    imports = [
      self.nixosModules.systm--ports-<service>
    ];

    # ============================================================================
    # OPTIONS - Define what can be configured
    # ============================================================================
    options = {
      services.<service>-nixlab = {
        enable = lib.mkEnableOption "<description>";

        port = lib.mkOption {
          type = lib.types.port;
          default = <port>;
          description = "Port for <Service> to listen on";
        };

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
        };

        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "<service>.example.com";
          description = "Domain name for nginx reverse proxy (optional)";
        };

        enableSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HTTPS with Let's Encrypt (requires domain)";
        };

        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/<service>";
          description = "Directory for <Service> data";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.<pkg>;
          defaultText = lib.literalExpression "pkgs.<pkg>";
          description = "The <Service> package to use";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "<service>";
          description = "User to run <Service> as";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "<service>";
          description = "Group to run <Service> as";
        };

        extraUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Extra users to add to the group";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open firewall ports";
        };

        secretsEnvFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to a sops-decrypted KEY=value env file for secrets.";
        };

        # --- service-specific options go here ---
      };
    };

    # ============================================================================
    # CONFIG - What happens when the service is enabled
    # ============================================================================
    config = lib.mkIf cfg.enable {
      assertions = [
        (nixlabLib.mkSslAssertion {
          inherit (cfg) enableSSL domain;
          moduleName = "services.<service>-nixlab";
        })
      ];

      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0770 ${cfg.user} ${cfg.group} -"
      ];

      users.groups.${cfg.group} = {};

      users.users = lib.mkMerge (
        [
          {
            ${cfg.user} = {
              isSystemUser = true;
              group = cfg.group;
              home = cfg.dataDir;
              description = "<Service> service user";
            };
          }
        ]
        ++ lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
        (map (u: {${u} = {extraGroups = [cfg.group];};})
          ([config.nixlab.mainUser] ++ cfg.extraUsers))
      );

      systemd.services.<service> = {
        description = "<Human-readable description>";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];

        serviceConfig =
          nixlabLib.mkServiceHardening {
            writablePaths = [cfg.dataDir];
          }
          // {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = cfg.dataDir;
            ExecStart = "${cfg.package}/bin/<binary>";
            Restart = "on-failure";
            RestartSec = "10s";
          }
          // lib.optionalAttrs (cfg.secretsEnvFile != null) {
            EnvironmentFile = cfg.secretsEnvFile;
          };
      };

      services.nginx.enable = lib.mkIf (cfg.domain != null) true;

      services.nginx.virtualHosts = nixlabLib.mkNginxVirtualHost {
        inherit (cfg) domain listenAddress port enableSSL;
      };

      networking.firewall.allowedTCPPorts =
        lib.mkIf cfg.openFirewall
        (nixlabLib.mkFirewallPorts {
          inherit (cfg) domain listenAddress;
          servicePort = cfg.port;
        });
    };
  };
}
/*
================================================================================
USAGE EXAMPLES
================================================================================

Minimal:
--------
services.<service>-nixlab = {
  enable = true;
};

================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  systemctl status <service>

Stream live logs:
  journalctl -u <service> -f
*/
```

And the matching `ports.nix` entry:

```nix
flake.nixosModules.systm--ports-<service> = {lib, ...}: {
  services.<service>-nixlab.port = lib.mkDefault <port>;
};
```

---

## 11. SOPS joiner modules (`nsops--*`)

Every module that has a secret gets a **second, companion file** in
`/nixlab/sops/<service>.nix`. Its entire job is: import the `servc--*`
module, add one `secretsFile` option pointing at a co-located
sops-encrypted file, and — when the service is enabled — decrypt the
secret(s) and feed the resulting path(s) into the `servc--*` module's own
sink option(s) (§4a). The `servc--*` module never references `sops.*`
directly; **only** the `nsops--*` module touches `sops.secrets`. This keeps
the base service module usable even on hosts that don't run sops-nix at
all.

### 11a. Skeleton

```nix
# /nixlab/sops/<service>.nix
{...}: {
  flake.nixosModules.nsops--<service> = {
    config,
    lib,
    self,
    ...
  }: let
    cfg = config.services.<service>-nixlab;
  in {
    imports = [self.nixosModules.servc--<service>-nixlab];

    options.services.<service>-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./<service>.yaml;
      defaultText = lib.literalExpression "./<service>.yaml";
      description = ''
        Path to the sops-encrypted <service> secrets file.
        Defaults to <service>.yaml co-located with this module.
        Override per-host if needed.
      '';
    };

    config = lib.mkIf cfg.enable {
      sops.secrets.<SERVICE>_SECRET_NAME = {
        sopsFile = cfg.secretsFile;
        owner = cfg.user;
        group = cfg.group;
        restartUnits = ["<service>.service"];
      };

      services.<service>-nixlab.<sinkOption> =
        config.sops.secrets.<SERVICE>_SECRET_NAME.path;
    };
  };
}
```

Fixed conventions:
- Module attr drops `-nixlab`/`-custom`: `nsops--<service>`, not
  `nsops--<service>-nixlab`.
- `secretsFile` option always lives on the *service's* option namespace
  (`services.<service>-nixlab.secretsFile`), not a separate `sops.*`
  namespace — so a host overriding it writes
  `services.<service>-nixlab.secretsFile = ../secrets/foo.yaml;` right next
  to the rest of that service's config.
- Default is always `./<service>.yaml`, co-located with the module file
  itself, with a matching `defaultText`.
- `restartUnits` is set on every secret so a secret rotation (re-running
  `sops updatekeys` + rebuild) restarts the right unit(s) automatically.
- `config = lib.mkIf cfg.enable { ... }` — the secret is only declared (and
  thus only needs to decrypt successfully) when the service is actually
  turned on.

### 11b. Sink strategies — pick the one that matches your secret's shape

| Pattern | When to use | Example |
|---|---|---|
| **Single secret → single sink option** | One opaque value or one KEY=value env file. | ollama (`webuiSecretKeyFile`), wiki-js (`appSecretFile`), homepage (`environmentFile`) |
| **`format = "dotenv"`** | The whole decrypted file already contains multiple `KEY=value` lines and should hand back one path for `EnvironmentFile`. | syncthing (`secretsEnvFile`, `format = "binary"` — file content *is* the env file), alertmanager (`format = "dotenv"`) |
| **`lib.genAttrs [...]  (_: {...})`** | Several independent secrets share the same `sopsFile`/owner/group/restartUnits — declare them all in one pass instead of repeating the attrset. | bookstack (4 DB/app secrets), node-red's credential secret list |
| **`sops.templates."<name>".content`** | You need to *compose* a new file (e.g. rename/relabel a decrypted value into `KEY=value` form) rather than hand back a raw secret path. Reference `config.sops.placeholder.<NAME>` inside the template — sops-nix substitutes the real decrypted value in at activation, so the plaintext never touches the Nix store. | node-red: builds `node-red-credentials.env` from `NODE_RED_CREDENTIAL_SECRET` |
| **`lib.mkMerge [...]` of several `lib.mkIf` blocks** | The joiner module has more than one independent secret-consuming concern (e.g. a main app secret plus an optional dashboard auth secret), each gated by its own condition. | hermes (`HERMES_ENV` unconditional + `HERMES_DASHBOARD_HTPASSWD` gated on `cfg.dashboard.basicAuth.enable`), matrix (per-user passwords + registration token with different owners) |
| **No sink option at all — rely on a fixed path or the upstream module's own option** | The consumer isn't a hand-rolled systemd unit you control (e.g. a podman/OCI compose file that already expects secrets at a conventional `/run/secrets/<NAME>` path, or an upstream nixpkgs module like `services.grafana` that has its own `admin_password_file`-style option). | bookstack (podman compose reads `/run/secrets/*` directly), grafana (`GRAFANA_ADMIN_PASSWORD` declared but no custom sink wired — consumed by grafana's own upstream option) |
| **Owner left as default (root) for `DynamicUser` services** | The consuming systemd unit uses `DynamicUser = true` (no persistent UNIX user to `chown` to). `EnvironmentFile=`/`EnvironmentFiles=` is read as root by systemd before the process drops privileges, so root ownership is correct, not a mistake. | alertmanager |
| **Standalone secrets module, no companion `servc--*` at all** | The secret isn't "owned" by one service module — it's cross-cutting (SSH keys deployed system-wide, wifi credentials for NetworkManager). Skip the `imports`/`secretsFile`-on-service-namespace conventions entirely; define its own option namespace (e.g. `nixlab.ssh-keys.*`) and manage files/symlinks directly via `systemd.tmpfiles.rules`. | ssh-keys, networking |

### 11c. Fill-in-the-blank sops joiner

```nix
# /nixlab/sops/<service>.nix
{...}: {
  flake.nixosModules.nsops--<service> = {
    config,
    lib,
    self,
    ...
  }: let
    cfg = config.services.<service>-nixlab;
  in {
    imports = [self.nixosModules.servc--<service>-nixlab];

    options.services.<service>-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./<service>.yaml;
      defaultText = lib.literalExpression "./<service>.yaml";
      description = ''
        Path to the sops-encrypted <service> secrets file.
        Defaults to <service>.yaml co-located with this module.
        Override per-host if needed.
      '';
    };

    config = lib.mkIf cfg.enable {
      sops.secrets.<SERVICE>_ENV = {
        sopsFile = cfg.secretsFile;
        owner = cfg.user;
        group = cfg.group;
        restartUnits = ["<service>.service"];
      };

      services.<service>-nixlab.secretsEnvFile =
        config.sops.secrets.<SERVICE>_ENV.path;
    };
  };
}
```

---

## 12. Prompt you can hand to Claude for a new module

Paste this back to Claude (with the blanks filled in) when you want a new
module generated in this exact house style:

> Generate a NixOS service module for **`<service>`** (package: `pkgs.<pkg>`,
> binary: `<binary>`) following the nixlab module template exactly:
> flake-parts `flake.nixosModules.servc--<service>-nixlab` naming,
> `options`/`config` split with `# REQUIRED:`/`# OPTIONAL: (default: X)`
> comments on every option, the standard option set (enable, port,
> listenAddress, domain, enableSSL, dataDir, package, user, group,
> extraUsers, openFirewall, secretsEnvFile-style sink option) plus these
> service-specific options: `<list>`. Use `nixlabLib.mkSslAssertion`,
> `nixlabLib.mkServiceHardening`, `nixlabLib.mkNginxVirtualHost`, and
> `nixlabLib.mkFirewallPorts` exactly as the template calls them. Add a
> matching `systm--ports-<service>` block for `ports.nix` with port
> `<port>`. Also generate the companion `/nixlab/sops/<service>.nix`
> `nsops--<service>` joiner module for these secrets: `<list, with a note on
> which sink strategy from §11b fits each>`. End the service module file
> with a `/* USAGE EXAMPLES / TROUBLESHOOTING */` doc block. [Optionally
> attach this template file for reference.]

---

*Reference source: extracted from your `modules.txt` export — 19 service
modules + `ports.nix`, spanning simple single-binary services (zola, ntfy),
multi-file services (glance, prometheus, homepage-dashboard, comfyui), and
non-HTTP services (waydroid) — plus a second export covering all 15
`nsops--*` secrets-joiner modules, the exact `nixlabLib` source
(`/nixlab/flake/nixos-lib.nix`), and the flake-parts builder/schema/data
files that wire `hostsMeta`/`usersMeta`/`hardwareMeta` into real
`nixosSystem` configs.*
