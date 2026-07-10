# nixlab

Modular NixOS configuration for Linux laptops, desktops, and homelab servers. Built on the **Dendritic Pattern** using **flake-parts** for composable, self-registering modules where every file declares its own outputs — including its own metadata and library functions.

Adapted from [Misterio77's nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) with inspiration from [EmergentMind](https://www.youtube.com/watch?v=YHm7e3f87iY&list=PLAWyx2BxU4OyERRTbzNAaRHK08DQ0DD_l&index=1), [Vimjoyer](https://www.youtube.com/@vimjoyer), and the broader NixOS community. Written almost entirely by Claude.

---

**Table of Contents**
- [Nix Ecosystem Terminology](#nix-ecosystem-terminology)
- [Architecture & Import Flow](#architecture--import-flow)
  - [Entry Point & Discovery](#entry-point--discovery)
  - [Central Orchestration Files](#central-orchestration-files)
  - [The Dendritic Pattern](#the-dendritic-pattern)
  - [Self-Exporting Module Schema](#self-exporting-module-schema)
  - [The `flake.lib` Registry](#the-flakelib-registry)
  - [Module Namespace & Naming](#module-namespace--naming)
  - [Two-Axis Metadata: Hosts & Users](#two-axis-metadata-hosts--users)
  - [Profile Composition](#profile-composition)
  - [Host Build Flow](#host-build-flow)
  - [Home-Manager Build Flow](#home-manager-build-flow)
  - [Coupling Principles](#coupling-principles)
  - [Secrets Management](#secrets-management)
- [Repository Layout](#repository-layout)
- [Usage](#usage)
  - [First Install](#first-install-on-a-new-machine)
  - [Daily Commands](#daily-commands)
  - [Adding a New Host](#adding-a-new-host)
  - [Adding a New Home User](#adding-a-new-home-user)
  - [Adding a New Service Module](#adding-a-new-service-module)
  - [Adding Secrets for a Service](#adding-secrets-for-a-service)

---

## Nix Ecosystem Terminology

<details>
<summary>Common terms and definitions <i>(click to expand)</i></summary>
<p></p>

- **Nix Language**: A domain-specific, declarative, pure, functional, lazily evaluated, dynamically typed programming language used to describe software builds and system configurations
  - **Nix Expressions**: Code written in the Nix language that defines how to build packages, assemble dependencies, or configure systems. Expressions evaluate to values and can be composed as functions
  - **Nix Values**: Immutable data types produced by evaluating Nix Expressions. Values are evaluated lazily (only when needed) and produce type errors at evaluation time
  - **Derivations**: Low-level build instructions generated from Expressions. A Derivation precisely specifies all inputs, dependencies, environment variables, and build steps required to produce a reproducible build output
- **Nix Package Manager**: A command-line toolset with an atomic update model that:
  1. evaluates Expressions into Derivations
  2. builds Packages from Derivations
  3. manages the Nix Store (including dependency tracking, garbage collection, and atomic upgrades/rollbacks)
  - **Nixpkgs**: A large, community-maintained repository of Expressions defining thousands of software packages, libraries, development tools, and NixOS modules
  - **Nix Store**: An immutable, content-addressed filesystem (typically `/nix/store`) that stores all build outputs and dependencies, ensuring isolation and reproducibility
- **NixOS**: A Linux distribution whose entire system configuration — packages, services, users, kernel options — is defined declaratively using the Nix language and built via the Nix Package Manager
- **Flakes**: A standardised schema for writing, referencing, and sharing Nix Expressions. A flake is a filesystem tree containing a `flake.nix` at its root that declares:
  - **inputs**: external dependencies (other flakes, nixpkgs channels, etc.)
  - **outputs**: what the flake produces (NixOS configurations, packages, modules, dev shells, etc.)
  - **flake.lock**: a version-pinning file that records exact revisions of all inputs for reproducibility
- **Modules**: Self-contained Nix files that declare options and implement configuration. The NixOS/home-manager module system merges modules together, resolving option definitions across all imported files into a final coherent system configuration
- **Overlays**: Functions of the form `final: prev: { ... }` that extend or modify a nixpkgs instance. Overlays can add new packages, override existing ones, or expose pinned package sets alongside the default channel
- **Priority / `mkDefault` / `mkForce`**: NixOS/home-manager options carry an implicit priority; lower wins. Plain assignment (`= value;`) sits at priority 100, `lib.mkDefault value` at 1000 (easily overridden), `lib.mkForce value` at 50 (hard to override). This is the mechanism nixlab uses deliberately to build precedence chains (see [Coupling Principles](#coupling-principles)) rather than relying on file-load order.

</details>

---

## Architecture & Import Flow

nixlab uses **flake-parts** and the **Dendritic Pattern**: configuration is organized around features rather than hostnames, with every file self-registering its own outputs — no central registry required, for either config modules *or* shared metadata/library functions.

- ### <ins>Entry Point & Discovery</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

`flake.nix` is a pure delegation layer. [flake-parts](https://github.com/hercules-ci/flake-parts) structures outputs as composable modules; [import-tree](https://github.com/vic/import-tree) auto-discovers every `.nix` file in each top-level directory. Each discovered file contributes to the shared `flake.*` / `perSystem.*` namespaces — adding a new file requires no changes to `flake.nix`. Files prefixed with `_` are leaf imports consumed by their parent module and hold no independent flake-output registration of their own (they're still discovered and evaluated by `import-tree`, but their content is a helper, not a standalone `flake.nixosModules.*`/`flake.homeModules.*` entry).

```nix
outputs = inputs @ { flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    imports = [
      (inputs.import-tree ./flake)    # → orchestration (lib, hosts-meta, users-meta, nixos-lib, checks, apps)
      (inputs.import-tree ./hardware) # → hardw--* nixosModules
      (inputs.import-tree ./home)     # → home--* homeModules
      (inputs.import-tree ./hosts)    # → hosts--* nixosModules + nixosConfigurations
      (inputs.import-tree ./modules)  # → servc--*, systm--* nixosModules
      (inputs.import-tree ./overlays) # → flake.overlays.*
      (inputs.import-tree ./shells)   # → perSystem.devShells.*
      (inputs.import-tree ./sops)     # → nsops--* nixosModules
    ];
  };
```

</details>

- ### <ins>Central Orchestration Files</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

A small number of concerns live in `flake/parts/` as conventional flake-parts files. All of them, including metadata and shared functions, are self-registering — none are imported by hardcoded relative path anymore.

| File | Responsibility | Output |
|------|---------------|--------|
| `lib.nix` | `mkHost`, `mkHomeUser`, `mkHomeUsersForHost`, `mkSystemUser`, `mkSystemUsersForHost` constructors — reads `self.lib.hostsMeta` / `self.lib.usersMeta` / `self.lib.nixlabLib`, injects nixpkgs, sops-nix, overlays, hostMeta into every host and home-manager user | `flake.lib.mkHost`, `.mkHomeUser`, `.mkHomeUsersForHost`, `.mkSystemUser`, `.mkSystemUsersForHost` |
| `hosts-meta.nix` | Per-host metadata: IPs, interfaces, architecture, nixpkgs input selection, `homeUsers`, `systemUsers`, `primaryUser` | `flake.lib.hostsMeta` |
| `users-meta.nix` | Per-user identity: git name/email, default home-manager profile, per-host overrides, SSH authorized keys, NixOS account facts (`isNormalUser`, `extraGroups`, `initialPassword`) | `flake.lib.usersMeta` |
| `nixos-lib.nix` | Shared NixOS helper functions (`mkNginxVirtualHost`, `mkFirewallPorts`, `mkServiceHardening`, `mkSslAssertion`) injected into every module as `nixlabLib` via `specialArgs` | `flake.lib.nixlabLib` |
| `options-lib.nix` | Declares `flake.lib` as a mergeable `lazyAttrsOf` option — the option declaration that makes the self-registration above possible | *(option declaration only)* |
| `options-home.nix` | Declares `flake.homeModules` as a mergeable `lazyAttrsOf` option | *(option declaration only)* |
| `nixpkgs.nix` | Configures `pkgs` for all `perSystem` blocks (`allowUnfree` + overlays) | `perSystem._module.args.pkgs` |
| `checks.nix` | Pre-commit hooks (alejandra, deadnix, merge-conflict guards) + formatter | `perSystem.checks`, `flake.formatter` |
| `apps.nix` | `build-all` app — validates every `nixosConfiguration` | `perSystem.apps.build-all` |
| `packages.nix` | Imports `pkgs/` into perSystem | `perSystem.packages` |

</details>

- ### <ins>The Dendritic Pattern</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Instead of configuring each machine individually, you assemble it from capabilities. **Features** > **Profiles** > **Hosts** — branching from general to specific: _"which features does this machine require?"_ This applies identically on both the NixOS side and the home-manager side.

1. **Feature Modules** — standalone services (`modules/`), secrets (`sops/`), or modules domain-grouped by shared behaviour
    - `hosts/common/` — `core/`, `desktop/`, `apps/`, `automation/`, `hardware/`
    - `home/common/` — `core/`, `apps/`, `shell/`
1. **Profiles** — (`profile-base`, `profile-desktop`, `profile-nas`) composed from **Feature Modules** into role-appropriate bundles, mirrored identically in `hosts/common/` and `home/common/`
1. **Host / User manifest** — metadata entries in `hosts-meta.nix` / `users-meta.nix` selecting profiles, plus a thin per-host file for genuinely unique feature selections
1. **`nixosConfigurations.<hostname>`** and **`home-manager.users.<username>`** — fully built outputs, generated by `mkHost` / `mkHomeUsersForHost` in `lib.nix`, with overlays, secrets, and cross-host metadata wired in automatically

</details>

- ### <ins>Self-Exporting Module Schema</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Every file is a flake-parts module that registers its own outputs directly. No central registry; the name is the only stable contract — files can be freely moved without breaking consumers.

```nix
# modules/nixos/glance/default.nix
{ self, ... }: {
  flake.nixosModules.servc--glance-nixlab = { config, lib, pkgs, nixlabLib, ... }: {
    imports = [ self.nixosModules.systm--ports-glance ];
    options.services.glance-nixlab = { enable = lib.mkEnableOption "glance"; ... };
    config = lib.mkIf cfg.enable { ... };
  };
}
```

```nix
# hosts/nixace.nix — one file, two outputs
{ self, ... }: {
  flake.nixosConfigurations.nixace = self.lib.mkHost {
    name = "nixace";
    modules = [
      self.nixosModules.hardw--zb17g4-p5
      self.nixosModules.hosts--nixace
      self.nixosModules.hosts--profl--base
      self.nixosModules.hosts--profl--desktop
      self.nixosModules.servc--bookstack-nixlab
      self.nixosModules.nsops--bookstack
    ];
  };

  flake.nixosModules.hosts--nixace = { ... }: {
    gShells.DE = "plasma6";
    blender.enable = true;
    steam.enable = true;
    # feature selections and genuinely unique service config only —
    # mainUser, home-manager users, and system accounts are all derived
    # from hosts-meta.nix / users-meta.nix, not hand-set here.
  };
}
```

</details>

- ### <ins>The `flake.lib` Registry</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

`flake.lib` works exactly like `flake.nixosModules`/`flake.homeModules`: it's a declared `lazyAttrsOf raw` option (in `options-lib.nix`) that flake-parts deep-merges across every file that contributes to it. This means shared metadata (`hostsMeta`, `usersMeta`) and shared functions (`nixlabLib`, `mkHost`, `mkHomeUser`, ...) can each live in their own self-registering file, with no file needing to know where another lives or import it by relative path.

```nix
# flake/parts/hosts-meta.nix
{lib, ...}: {
  flake.lib.hostsMeta = {
    nixace = { address = "10.0.0.200"; homeUsers = ["temhr"]; systemUsers = ["temhr" "guest"]; primaryUser = "temhr"; ... };
    # ...
  };
}
```

```nix
# flake/parts/lib.nix — consumes, never imports by path
{self, inputs, ...}: let
  hostsMeta = self.lib.hostsMeta;
  usersMeta = self.lib.usersMeta;
  nixlabLib = self.lib.nixlabLib;
in {
  flake.lib = {inherit mkHost mkHomeUser mkHomeUsersForHost mkSystemUser mkSystemUsersForHost;};
}
```

Because `self` is resolved lazily by flake-parts, `lib.nix` can reference `self.lib.hostsMeta` before that attribute has "arrived" from its own file — the same laziness trick that already lets any module reference `self.nixosModules.*` regardless of load order. This is why the metadata files (`hosts-meta.nix`, `users-meta.nix`) can live anywhere in the tree without breaking anything that consumes them.

</details>

- ### <ins>Module Namespace & Naming</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

All NixOS modules register under `flake.nixosModules`; all home-manager modules register under `flake.homeModules`. The double-dash convention encodes a two-level hierarchy in a flat namespace — all cross-file references use `self.nixosModules.*` / `self.homeModules.*`, never filesystem paths.

| Prefix | Layer |
|--------|-------|
| `hardw--` | Physical machine hardware |
| `hosts--<hostname>` | Host identity + feature selections |
| `hosts--profl--` | NixOS profile compositions (base, desktop, nas) |
| `hosts--core--` | Universal NixOS modules (all hosts) |
| `hosts--deskt--` | Desktop-only NixOS modules |
| `hosts--apps--` | Toggleable NixOS application modules |
| `hosts--autom--` | Scheduled tasks and automation |
| `hosts--hardw--` | Shared hardware concerns |
| `hosts--debug--` | Opt-in diagnostics (never in any profile) |
| `home--profl--` | Home-manager profile compositions (base, desktop) |
| `home--core--` | Universal home-manager modules (every user) |
| `home--apps--` | Toggleable home-manager application modules |
| `home--shell--` | Shell/dotfile modules |
| `nsops--` | sops-nix secret wiring modules |
| `servc--` | Self-hosted service modules |
| `systm--` | Cross-cutting system defaults (e.g. per-service port defaults) |

```
# nix flake show (abbreviated)
├───nixosConfigurations
│   ├───nixace, nixnas1, nixnas2, nixsun, nixtop, nixvat, nixzen
├───nixosModules
│   ├───hardw--zb17g4-p5, hosts--nixace, hosts--profl--base, servc--glance-nixlab, ...
├───homeModules
│   ├───home--profl--base, home--profl--desktop, home--core--config-git, home--apps--browsers, ...
```

</details>

- ### <ins>Two-Axis Metadata: Hosts & Users</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

User identity and host placement are deliberately independent axes — a user is never hardcoded into a per-combo file. This is what lets any number of users mix and match across any number of hosts (e.g. `temhr` on `nixace`; `temhr` and `guest` on `nixvat`; `guest` and `rhmet` on `nixsun`) without per-combo boilerplate.

**Axis 1 — `usersMeta` (who, independent of where):**
```nix
# flake/parts/users-meta.nix
flake.lib.usersMeta = {
  temhr = {
    gitName = "Temhr";
    gitEmail = "9110264+Temhr@users.noreply.github.com";
    defaultProfile = "desktop";
    hostOverrides = {
      nixnas1 = { profile = "minimal"; };
      nixnas2 = { profile = "minimal"; };
      nixace  = { extraModules = [ self.homeModules.temhr-nixace-extra ]; };
    };
    # NixOS account facts, independent of home-manager:
    isNormalUser = true;
    sshAuthorizedKeys = [ "ssh-ed25519 AAAA..." ];
    extraGroups = [ "wheel" "networkmanager" "video" "render" ];
  };
};
```

**Axis 2 — `hostsMeta` (where, independent of who):**
```nix
# flake/parts/hosts-meta.nix
nixace = mkHostMeta {
  address = "10.0.0.200";
  homeUsers   = [ "temhr" ];          # gets a home-manager profile
  systemUsers = [ "temhr" "guest" ];  # gets a NixOS account
  primaryUser = "temhr";              # drives nixlab.mainUser
};
```

**Generators turn metadata into config, with zero per-combo files required by default:**
```nix
mkHomeUsersForHost   = hostName: lib.genAttrs hostsMeta.${hostName}.homeUsers   (mkHomeUser hostName ...);
mkSystemUsersForHost = hostName: lib.genAttrs hostsMeta.${hostName}.systemUsers (mkSystemUser ...);
```
`nixlab.mainUser` is itself derived — `lib.mkDefault hostsMeta.<host>.primaryUser` — rather than hand-copied into every host file.

**Real per-combo files are an escape hatch, not the default.** `home/users/<username>-<hostname>.nix` (referenced via `hostOverrides.<host>.extraModules`) is created only when a specific user@host combination has genuinely unique content (e.g. GPU tooling only relevant to `temhr` on `nixace`) — mirroring exactly how sparse `hosts/nixzen.nix` and substantial `hosts/nixace.nix` coexist: file richness tracks real uniqueness, not a uniform template.

</details>

- ### <ins>Profile Composition</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Every `nixosConfiguration` and every generated home-manager user composes from the same three-tier shape:

**NixOS side** (`hosts/common/profile-*.nix`):
- `hosts--profl--base` — boot loader, networking, nix settings, ssh, sops, monitoring stack, home-manager wiring, automation timers; imported by every host
- `hosts--profl--desktop` — dev/gaming/media/productivity/virtualization toggle modules, desktop-only concerns (firefox, flatpak, gui-shells); imported by desktop/laptop hosts
- `hosts--profl--nas` — NAS-specific automation (phone media backup); imported by NAS hosts

**Home-manager side** (`home/common/profile-*.nix`):
- `home--profl--base` — git, ssh, fastfetch, XDG folders, ephemeral-app launchers, bash shell integration; imported by every user
- `home--profl--desktop` — browsers, terminal emulators, virt-manager dconf tweak; imported when a user's resolved profile is `"desktop"`

</details>

- ### <ins>Host Build Flow</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

```
hosts/<hostname>.nix
  → self.lib.mkHost { name; modules; }
    → asserts hostsMeta.<hostname> exists
    → resolves nixpkgsInput (stable/unstable) + system architecture
    → injects specialArgs: nixlabLib, allHosts, hostMeta, self, inputs
    → composes: mkCommonModules ++ modules ++ [ hostName, hostId, pkgs pin, registry pin ]
    → hostLib.nixosSystem { ... }
      → flake.nixosConfigurations.<hostname>
```

</details>

- ### <ins>Home-Manager Build Flow</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

```
hosts--core--home-manager-config (imported by hosts--profl--base)
  → home-manager.users = self.lib.mkHomeUsersForHost config.networking.hostName
    → for each username in hostsMeta.<hostname>.homeUsers:
      → self.lib.mkHomeUser { username; hostName; }
        → resolves usersMeta.<username>.hostOverrides.<hostName> or {} → profile, extraModules
        → imports: home--profl--base ++ (optional) home--profl--desktop ++ extraModules
        → sets home.username/homeDirectory/stateVersion, programs.git identity
```

NixOS system accounts follow the identical shape via `mkSystemUsersForHost` / `hostsMeta.<hostname>.systemUsers`, consumed by `hosts/common/core/_users/users-sys.nix` — so a username existing on a host as a login account and existing as a home-manager profile are two independently-controlled facts, not one hardcoded assumption.

</details>

- ### <ins>Coupling Principles</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

A few conventions in this repo exist specifically to keep coupling visible and manageable rather than accidental:

**Port precedence** — three tiers, highest to lowest, using NixOS's own priority mechanism rather than convention alone:
1. **Host file** — plain assignment (`services.foo-nixlab.port = 9999;`) always wins
2. **`modules/ports.nix`** (`systm--ports-*`) — `lib.mkDefault <value>`, the fleet-wide sensible default
3. **Service module's own option `default`** — lowest priority, a safety net if `ports.nix` isn't imported for that service at all

**Service hardening** — every service's `serviceConfig` should route through `nixlabLib.mkServiceHardening` rather than hand-rolling `systemd` sandboxing:
```nix
serviceConfig = nixlabLib.mkServiceHardening {
  writablePaths = [ cfg.dataDir ];
  allowNetwork  = true;   # default; set false for network-isolated services
  allowDevices  = false;  # set true for GPU/hardware access — also relaxes
                          # ProtectKernelModules/Tunables/RestrictNamespaces
  allowJIT      = false;  # set true for JIT-compiled runtimes (Next.js, Node.js,
                          # CUDA) — relaxes MemoryDenyWriteExecute/SystemCallFilter
} // { Type = "simple"; ExecStart = "..."; ... };
```
A one-off exception (e.g. a specific exporter needing extra syscall families) should still start from this helper and override only the specific field that's genuinely different — not bypass it entirely, which silently drops every other protection the helper provides.

**Single source of truth for generated aggregates** — when multiple files need the same derived fact (e.g. "which services are enabled, and what group do they belong to" for a dashboard), that fact lives in one `_<name>-registry.nix`-style file, imported by every consumer, rather than copy-pasted maps that can silently drift out of sync (see `modules/nixos/homepage-dashboard/_service-registry.nix`).

</details>

- ### <ins>Secrets Management</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix), age-encrypted, one `.yaml` file per service under `sops/`. Each service's `nsops--<service>` module:
- `imports = [ self.nixosModules.servc--<service>-nixlab ];` — a structural dependency, not a runtime assertion, since the secret is meaningless without the service module that consumes it
- Declares `sops.secrets.<KEY> = { sopsFile = ./<service>.yaml; owner = ...; restartUnits = [...]; };`
- Wires the decrypted path into the service's own option (e.g. `services.<service>-nixlab.secretsEnvFile = config.sops.secrets.<KEY>.path;`) — never reaches into `systemd.services.*` directly, and never touches an unrelated option (e.g. a secrets module should not also flip a service's `checkConfig` — that belongs to the service module deriving its own default from `environmentFile != null`)

`sops.age.keyFile` is set once, globally, in `hosts--core--sops` (or equivalent core module) — never inside an optional feature module, since every secret on every host depends on it regardless of which optional features are enabled.

</details>

---

## Repository Layout

```
nixlab/
├── flake.nix                          # pure delegation to flake-parts + import-tree
├── flake.lock
├── .sops.yaml                         # sops-nix age recipient rules
│
├── flake/parts/                       # orchestration — see Central Orchestration Files
│   ├── apps.nix
│   ├── checks.nix
│   ├── hosts-meta.nix                 # flake.lib.hostsMeta
│   ├── lib.nix                        # mkHost, mkHomeUser(s), mkSystemUser(s)
│   ├── nixos-lib.nix                  # flake.lib.nixlabLib
│   ├── nixpkgs.nix
│   ├── options-home.nix
│   ├── options-lib.nix
│   ├── packages.nix
│   └── users-meta.nix                 # flake.lib.usersMeta
│
├── hardware/                          # hardw--* modules, one file per physical machine
│   ├── m720q-*.nix, ...
│   ├── zb*.nix, ...
│   └── common/
│       ├── global.nix
│       ├── _global/                   # default.nix, hardware-configuration.nix, mounts.nix
│       └── optional/                  # driver-nvidia.nix, zfs-pool-rename.nix, mount-*.nix
│
├── hosts/                             # hosts--* modules + nixosConfigurations
│   ├── nix*.nix, ...
│   └── common/
│       ├── _host-template.nix         # reference menu — never imported by the flake
│       ├── profile-*.nix, ...
│       ├── apps/                      # development, education, games, media, productivity, virtualizations
│       ├── automation/                # backup-home, ...
│       ├── core/                      # boot-loader, ...
│       │   └── users.nix              # users-main.nix, users-hm.nix, users-sys.nix
│       ├── debug/                     # diagnose.nix — opt-in only, never in any profile
│       ├── desktop/                   # cache-tmpfs, firefox, flatpak, gui-shells, ignore-lid
│       └── hardware/                  # audio, bluetooth, power-management
│
├── home/                              # home--* modules, mirrors hosts/ structure
│   ├── common/
│   │   ├── profile-*.nix, ...
│   │   ├── apps/                      # browsers, terminal-emulators, config-virt-manager
│   │   ├── core/                      # config-*, ephemeral-apps, system, utilities
│   │   └── shell/
│   │       └── bash.nix               # directory-driven alias loading via readDir
│   └── files/bash/                    # actual dotfile content — .bash_profile, .bashrc, .bash/*
│
├── modules/                           # servc--*, systm--* — self-hosted service modules
│   ├── ports.nix                      # systm--ports-* per-service defaults (mkDefault)
│   └── nixos/
│       ├── bookstack.nix, ...
│       ├── comfyui/                   # comfyui-p5000, comfyui-extensions, comfyui-models
│       ├── glance/                    # default.nix, _glance-pages.nix
│       ├── homepage-dashboard/        # default.nix, ...
│       └── monitoring/
│           ├── alertmanager/, grafana/ (+ dashboards/*.json), ntfy/
│           ├── loki/                  # default.nix, maintenance-logger.sh
│           └── prometheus/            # default.nix + _internals/ (config, options, alerts,
│                                      # scrape-configs, exporters/, extras/, services/)
│
├── sops/                              # nsops--* modules — one .nix + one .yaml per service
│   └── alertmanager, ...
│
├── overlays/                          # flake.overlays.*
│   ├── default.nix
│   └── _comfyui-p5000.nix, _ollama-p5000.nix, _pytorch-p5000.nix
│
├── shells/                            # perSystem.devShells.*
│   ├── default-shell.nix, minimal.nix, container.nix
│   ├── data.nix, mesa.nix, nix-dev.nix, python.nix, repast.nix, rust.nix, security.nix
│
├── cachix/                            # per-cache substituter config
│   └── cuda-maintainers.nix, ghostty.nix, nix-community.nix
│
├── pkgs/                              # perSystem.packages
│   └── default.nix
│
└── bin/                               # standalone utility scripts, not flake outputs
    └── home-directory-organizer-script.sh, repast-bs.sh
```

</details>

---

## Usage

- ### <ins>First Install (on a new machine)</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

```bash
# Boot a NixOS installer, partition/format disks, mount to /mnt
nixos-generate-config --root /mnt
git clone https://github.com/Temhr/nixlab.git /mnt/home/temhr/nixlab
cd /mnt/home/temhr/nixlab

# Add hardware config — see "Adding a New Host" below
# Provision /var/lib/sops-nix/key.txt (age key) before first switch, or
# secrets will fail to decrypt on boot.

nixos-install --root /mnt --flake .#<hostname>
reboot
```

</details>

- ### <ins>Daily Commands</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

```bash
lswitch   # sudo nixos-rebuild switch --flake $NIXLAB
ltest     # sudo nixos-rebuild test   --flake $NIXLAB
lboot     # sudo nixos-rebuild boot   --flake $NIXLAB && sudo reboot
lfup      # nix flake update         --flake $NIXLAB
nixhelp   # print the full alias reference

nix flake check          # eval + pre-commit checks (formatting, dead code, merge conflicts)
nix run .#build-all      # build every nixosConfiguration without switching
nix fmt                  # run alejandra across the whole tree
```

</details>

- ### <ins>Adding a New Host</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

#### 1. Add host metadata to `flake/parts/hosts-meta.nix`

```nix
<hostname> = mkHostMeta {
  address = "10.0.0.XXX";
  ethIface = "enp0s31f6";            # Find with: ip link
  wifiIface = "wlp3s0";              # Find with: ip link (omit if no wifi)
  hostId = "XXXXXXXX";               # Generate with: head -c 8 /etc/machine-id
  nixpkgsInput = "nixpkgs-stable";   # or "nixpkgs-unstable"
  homeUsers = [ "temhr" ];           # usernames that get a home-manager profile here
  systemUsers = [ "temhr" "guest" ]; # usernames that get a NixOS account here
  primaryUser = "temhr";            # drives nixlab.mainUser automatically
};
```

#### 2. Create hardware module `hardware/<model>.nix`

```nix
{ self, ... }: {
  flake.nixosModules.hardw--<model> = { lib, ... }: {
    # Paste output from nixos-generate-config here:
    boot.initrd.availableKernelModules = [ ... ];
    fileSystems."/" = { ... };
    swapDevices = [ ... ];
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  };
}
```

#### 3. Create host configuration `hosts/<hostname>.nix`

```nix
{ self, ... }: {
  flake.nixosConfigurations.<hostname> = self.lib.mkHost {
    name = "<hostname>";
    modules = [
      self.nixosModules.hardw--<model>
      self.nixosModules.hosts--<hostname>
      self.nixosModules.hosts--profl--base      # required for all hosts
      self.nixosModules.hosts--profl--desktop   # desktop/laptop machines
      # self.nixosModules.hosts--profl--nas     # NAS/server machines
      self.nixosModules.servc--glance-nixlab
      self.nixosModules.nsops--glance
    ];
  };

  flake.nixosModules.hosts--<hostname> = { config, pkgs, ... }: {
    gShells.DE = "plasma6";   # only needed if using profile-desktop
    blender.enable = true;
    steam.enable = true;
    libreoffice.enable = true;
    # nixlab.mainUser is derived from hostsMeta.<hostname>.primaryUser —
    # do not hand-set it here unless this one host genuinely needs to differ.

    services.glance-nixlab = {
      enable = true;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      dataDir = "/data/glance";
    };

    system.stateVersion = "24.11";
  };
}
```

#### 4. Deploy

```bash
cd ~/nixlab
git add -A            # new/untracked files are invisible to the flake until staged
nix flake check
sudo nixos-rebuild switch --flake .#<hostname>
```

</details>

- ### <ins>Adding a New Home User</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Home-manager users are **generated**, not hand-written per host. Adding a new user, or adding an existing user to a new host, is a metadata change only.

#### 1. Add the user's identity to `flake/parts/users-meta.nix`

```nix
rhmet = {
  gitName = "Rhmet";
  gitEmail = "rhmet@example.com";
  defaultProfile = "desktop";
  hostOverrides = {};   # empty unless this user needs a different profile on a specific host

  isNormalUser = true;
  sshAuthorizedKeys = [ "ssh-ed25519 AAAA... rhmet" ];
  extraGroups = [ "networkmanager" ];
};
```

#### 2. Add the username to the target host(s) in `flake/parts/hosts-meta.nix`

```nix
nixsun = mkHostMeta {
  ...
  homeUsers = [ "guest" "rhmet" ];
  systemUsers = [ "guest" "rhmet" ];
};
```

That's it — no `home/users/rhmet-nixsun.nix` file is required. `mkHomeUsersForHost` and `mkSystemUsersForHost` will generate both the home-manager profile and the NixOS account automatically on the next rebuild.

#### 3. (Only if genuinely needed) Add a per-combo extra module

If one specific user@host combination needs unique content beyond the shared profile (e.g. GPU tooling only relevant on one machine), create a real file and wire it through `hostOverrides`:

```nix
# home/users/temhr-nixace.nix
{ ... }: {
  flake.homeModules.temhr-nixace-extra = { pkgs, ... }: {
    home.packages = with pkgs; [ nvtopPackages.nvidia cudatoolkit ];
    home.sessionVariables = { CUDA_VISIBLE_DEVICES = "0"; };
  };
}
```
```nix
# flake/parts/users-meta.nix
temhr.hostOverrides.nixace = { extraModules = [ self.homeModules.temhr-nixace-extra ]; };
```

#### 4. Deploy

```bash
git add -A
nix flake check
nix eval .#nixosConfigurations.<hostname>.config.home-manager.users.<username>.home.packages
sudo nixos-rebuild switch --flake .#<hostname>
```

</details>

- ### <ins>Adding a New Service Module</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Service modules live in `modules/nixos/<service>/`. Secrets are managed separately in `sops/`.

> Shared helpers (`mkNginxVirtualHost`, `mkFirewallPorts`, `mkServiceHardening`, `mkSslAssertion`) are available in any module via `{ nixlabLib, ... }:` — see `flake/parts/nixos-lib.nix` for usage examples, and [Coupling Principles](#coupling-principles) for `mkServiceHardening`'s `allowNetwork`/`allowDevices`/`allowJIT` flags.

#### 1. (Optional) Add a dedicated port default `modules/ports.nix`

```nix
flake.nixosModules.systm--ports-<service> = { lib, ... }: {
  services.<service>-nixlab.port = lib.mkDefault 8080;
};
```

#### 2. Create the module `modules/nixos/<service>/default.nix`

```nix
{ self, ... }: {
  flake.nixosModules.servc--<service>-nixlab = { config, lib, pkgs, nixlabLib, ... }:
  let cfg = config.services.<service>-nixlab; in {
    imports = [ self.nixosModules.systm--ports-<service> ];

    options.services.<service>-nixlab = {
      enable = lib.mkEnableOption "<service>";
      port = lib.mkOption { type = lib.types.port; default = 8080; };
      listenAddress = lib.mkOption { type = lib.types.str; default = "127.0.0.1"; };
      dataDir = lib.mkOption { type = lib.types.str; default = "/var/lib/<service>"; };
      openFirewall = lib.mkOption { type = lib.types.bool; default = false; };
      secretsEnvFile = lib.mkOption { type = lib.types.nullOr lib.types.path; default = null; };
    };

    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = [ "d ${cfg.dataDir} 0770 <service> <service> -" ];

      systemd.services.<service> = {
        description = "<Service> daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = nixlabLib.mkServiceHardening {
          writablePaths = [ cfg.dataDir ];
        } // {
          ExecStart = "${pkgs.<service>}/bin/<service> --port ${toString cfg.port}";
          User = "<service>";
          Group = "<service>";
          EnvironmentFile = lib.mkIf (cfg.secretsEnvFile != null) cfg.secretsEnvFile;
        };
      };

      users.users.<service> = { isSystemUser = true; group = "<service>"; };
      users.groups.<service> = {};

      networking.firewall.allowedTCPPorts =
        lib.mkIf cfg.openFirewall (nixlabLib.mkFirewallPorts {
          inherit (cfg) listenAddress;
          domain = null;
          servicePort = cfg.port;
        });
    };
  };
}
```

#### 3. Use in a host

```nix
# hosts/<hostname>.nix — modules = [...]:
self.nixosModules.servc--<service>-nixlab
self.nixosModules.nsops--<service>   # if it has secrets

# hosts/<hostname>.nix — config:
services.<service>-nixlab = {
  enable = true;
  openFirewall = true;
  dataDir = "/data/<service>";
  # port left unset — resolves via ports.nix's mkDefault, or override here
  # with a plain assignment if this one host genuinely needs a different port.
};
```

#### 4. Validate and deploy

```bash
git add -A
nix flake check
sudo nixos-rebuild switch --flake .#<hostname>
```

</details>

- ### <ins>Adding Secrets for a Service</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

#### 1. Create `sops/<service>.nix`

```nix
{ self, ... }: {
  flake.nixosModules.nsops--<service> = { config, lib, ... }:
  let cfg = config.services.<service>-nixlab; in {
    imports = [ self.nixosModules.servc--<service>-nixlab ]; # structural dependency, not a runtime assertion

    options.services.<service>-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./<service>.yaml;
    };

    config = lib.mkIf cfg.enable {
      sops.secrets."<service>_env" = {
        sopsFile = cfg.secretsFile;
        owner = "<service>";
        restartUnits = ["<service>.service"];
      };
      services.<service>-nixlab.secretsEnvFile =
        config.sops.secrets."<service>_env".path;
    };
  };
}
```

#### 2. Create and encrypt the secrets file

```bash
sops sops/<service>.yaml
# write KEY=value lines, save — sops encrypts on write
```

#### 3. Import in the host

```nix
# hosts/<hostname>.nix — modules = [...]:
self.nixosModules.nsops--<service>
```

#### 4. Validate and deploy

```bash
git add -A
nix flake check
sudo nixos-rebuild switch --flake .#<hostname>
```

</details>

---

## Acknowledgments

- [Misterio77](https://github.com/Misterio77/nix-starter-configs) — Base configuration structure
- [EmergentMind](https://www.youtube.com/@EmergentMind) — Educational video series
- [Vimjoyer](https://www.youtube.com/@vimjoyer) — Educational video series
- The NixOS community for extensive documentation and support
- Little, by little, by a lot: rewritten almost entirely with Claude
