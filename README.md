# nixlab

Modular NixOS configuration for laptops, desktops, and homelab servers — built on the **Dendritic Pattern** with **flake-parts**, where every file self-registers its own output (including its own metadata and library functions).

New here? [Architecture at a Glance](#architecture-at-a-glance) is the one-minute version; [Core Concepts](#core-concepts) is the canonical explanation everything else links back to. Looking for monitoring? It lives in its own flake; [Observability](#observability-external-flake) explains how nixlab consumes it, and [Deployment & Automation](#deployment--automation) explains how changes reach the hosts.

Adapted from [Misterio77's nix-starter-configs](https://github.com/Misterio77/nix-starter-configs), with inspiration from [EmergentMind](https://www.youtube.com/@EmergentMind), [Vimjoyer](https://www.youtube.com/@vimjoyer), and the NixOS community. Rewritten almost entirely with Claude.

---

**Table of Contents**
- [Nix Ecosystem Terminology](#nix-ecosystem-terminology)
- [Architecture at a Glance](#architecture-at-a-glance)
- [Core Concepts](#core-concepts)
  - [Self-Registering Modules](#self-registering-modules)
  - [The Dendritic Pattern](#the-dendritic-pattern)
  - [Three-Axis Metadata: Hardware, Hosts & Users](#three-axis-metadata-hardware-hosts--users)
  - [Builder Functions](#builder-functions)
- [Architecture & Import Flow](#architecture--import-flow)
  - [Entry Point & Orchestration Files](#entry-point--orchestration-files)
  - [Self-Registration in Practice](#self-registration-in-practice)
  - [Module Naming & Profile Composition](#module-naming--profile-composition)
  - [Build Flows](#build-flows)
  - [Coupling Principles](#coupling-principles)
  - [Secrets Management](#secrets-management)
- [Repository Reference](#repository-reference)
  - [Repository Layout](#repository-layout)
  - [Top-Level Folder Reference](#top-level-folder-reference)
- [Observability (external flake)](#observability-external-flake)
- [Deployment & Automation](#deployment--automation)
- [Usage](#usage)
  - [First Install](#first-install-on-a-new-machine)
  - [Daily Commands](#daily-commands)
  - [Adding a New Host](#adding-a-new-host)
  - [Adding a New Home User](#adding-a-new-home-user)
  - [Adding a New Service Module](#adding-a-new-service-module)
  - [Adding Secrets for a Service](#adding-secrets-for-a-service)
- [Acknowledgments](#acknowledgments)

---

## Nix Ecosystem Terminology

<details>
<summary>Common terms and definitions <i>(click to expand)</i></summary>
<p></p>

- **Nix Language** — declarative, pure, functional, lazily-evaluated language for describing builds/configs
  - **Nix Expressions** — code that defines builds/config; evaluates to Values, composes as functions
  - **Nix Values** — immutable, lazily-evaluated results of Expressions; type errors surface at evaluation time
  - **Derivations** — low-level build instructions (inputs, deps, env, steps) generated from Expressions
- **Nix Package Manager** — evaluates Expressions → Derivations → Packages, and manages the Nix Store (dependency tracking, GC, atomic upgrades/rollbacks)
  - **Nixpkgs** — community repo of Expressions for packages, libraries, dev tools, NixOS modules
  - **Nix Store** — immutable, content-addressed filesystem (`/nix/store`) holding build outputs
- **NixOS** — a Linux distro whose entire config (packages, services, users, kernel) is declared in Nix and built via the package manager
- **Flakes** — standardized schema for Nix Expressions. A flake is a tree with a root `flake.nix` declaring:
  - **inputs** — external deps (other flakes, nixpkgs channels)
  - **outputs** — what it produces (configs, packages, modules, dev shells)
  - **flake.lock** — pinned exact revisions of all inputs
- **Modules** — self-contained files declaring options/config; the NixOS/home-manager module system merges them into one final config
- **Overlays** — `final: prev: {...}` functions that extend/override a nixpkgs instance
- **Priority / `mkDefault` / `mkForce`** — options carry an implicit priority, lower wins: plain `= value;` = 100, `lib.mkDefault` = 1000 (easily overridden), `lib.mkForce` = 50 (hard to override). nixlab uses this deliberately to build precedence chains (see [Coupling Principles](#coupling-principles)) instead of relying on file-load order.

</details>

---

## Architecture at a Glance

Three independent metadata axes describe *what exists* (hardware, hosts, users). Three builder functions turn that metadata into *real configuration*. Every file that participates — metadata, builder, or module — registers its own output; there's no central list.

```
                              flake.nix
              ┌───────────────────┼───────────────────┐
              ▼                   ▼                   ▼
        hardwareMeta           hostsMeta          usersMeta          ← data/
      (physical facts)     (network identity)      (who)
              ▼                   ▼                   ▼
      mkHardwareProfile         mkHost          mkHomeUsersForHost   ← builders/
              └───────────────────┼───────────────────┘
                                  ▼
                        Profile Composition
              (hardware/, hosts/, home/ profile-*.nix)
                                  ▼
        flake.nixosConfigurations.<host>  +  home-manager.users.<user>
```

[Core Concepts](#core-concepts) explains the ideas this diagram assumes; [Architecture & Import Flow](#architecture--import-flow) walks the same picture file-by-file.

---

## Core Concepts

The four recurring ideas in this repo, explained once here — every other section links back instead of re-explaining.

### Self-Registering Modules

Every contributing file registers its own output, keyed by its own name. Only files nested inside underscored `_directories` are imported by relative path, and only by their owning module's entry file or by each other; everything else consumes a registered name (`self.nixosModules.*`, `self.lib.*`).

| Mechanism | How it works |
|---|---|
| **Discovery** | [import-tree](https://github.com/vic/import-tree) walks each top-level directory (`flake/`, `hosts/`, `home/`, ...) and evaluates every `.nix` file **except paths containing an `_`-prefixed segment**. Adding a file requires no edit anywhere else — see [Entry Point & Orchestration Files](#entry-point--orchestration-files). |
| **Registration** | Each file assigns into `flake.nixosModules.<name>`, `flake.homeModules.<name>`, or `flake.lib.<name>` — all declared as mergeable options (`lazyAttrsOf raw`, in `flake/schema/options.nix`), so [flake-parts](https://github.com/hercules-ci/flake-parts) deep-merges every contribution into one attrset. |
| **Consumption** | Other files reference results only by registered name (`self.nixosModules.foo`, `self.lib.bar`) — never by path. Since `self` resolves lazily, this works regardless of tree position or evaluation order — see [Self-Registration in Practice](#self-registration-in-practice). |
| **The contract** | Nothing is wired by path, so a file can move anywhere without breaking its dependents, as long as its registered name stays the same. |

This is one pattern, not two — it applies identically to config modules (`nixosModules`/`homeModules`) and to metadata/library functions (`flake.lib`).

### The Dendritic Pattern

Machines are assembled from capabilities rather than configured individually: **Features → Profiles → Hosts**, general to specific — *"which features does this machine require?"* Applies identically on the NixOS and home-manager sides.

1. **Feature Modules** — standalone services (`modules/`), secrets (`sops/`), or modules grouped by shared behaviour (`hosts/common/{core,desktop,apps,automation,hardware}`, `home/common/{core,apps,shell}`)
2. **Stacks & adapters** — `stacks/` holds (a) *stacks*: bundles that compose ≥2 atomic service modules which must communicate (datasource provisioning, scrape targets, alert routing) behind one aggregator option surface, and (b) *adapters*: thin modules that translate nixlab's own facts (host metadata, the service registry, encrypted files) into the option surface of an **external flake** such as [observability](#observability-external-flake). Only warranted when cross-service or cross-repo wiring would otherwise pollute an atomic module — see [Top-Level Folder Reference](#top-level-folder-reference)
3. **Profiles** — (`profile-base`, `profile-desktop`, `profile-nas`) role-appropriate bundles of Feature Modules + Stacks, mirrored across `hosts/common/` and `home/common/` — see [Module Naming & Profile Composition](#module-naming--profile-composition)
4. **Host / User manifest** — metadata in `flake/data/hosts-meta.nix` / `users-meta.nix` selecting profiles, plus a thin per-host file for genuinely unique selections — see [Three-Axis Metadata](#three-axis-metadata-hardware-hosts--users)
5. **Final outputs** — `nixosConfigurations.<hostname>` and `home-manager.users.<username>`, generated by the [Builder Functions](#builder-functions), with overlays/secrets/cross-host metadata wired in automatically

### Three-Axis Metadata: Hardware, Hosts & Users

Physical hardware, host identity, and user identity are three deliberately independent axes — none hardcoded into another. This lets any users mix and match across any hosts (e.g. `temhr` on `nixace`; `temhr`+`guest` on `nixvat`; `guest`+`rhmet` on `nixsun`), and lets one hardware profile (e.g. `workstation-nvidia`) back multiple machines, with no per-combo boilerplate.

| Axis | Question | Lives in | Built via | Independent of |
|---|---|---|---|---|
| `hardwareMeta` | What is this physical box? | `flake/data/hardware-meta.nix` | `mkMachineMeta` (`flake/schema/hardware.nix`) | hostname, users |
| `hostsMeta` | Which network identity, which users? | `flake/data/hosts-meta.nix` | `mkHostMeta` (`flake/schema/hosts.nix`) | physical hardware |
| `usersMeta` | Who, independent of machine? | `flake/data/users-meta.nix` | plain attrset (validated by option decls) | hostname, hardware |

**`hardwareMeta`** — keyed by **machine name**, not hostname (see [Module Naming & Profile Composition](#module-naming--profile-composition) for why those differ):
```nix
# flake/data/hardware-meta.nix — mkMachineMeta lives in flake/schema/hardware.nix
flake.lib.hardwareMeta = {
  zb17g1-k3 = mkMachineMeta {
    cpuVendor = "intel";
    initrdAvailableKernelModules = ["xhci_pci" "ehci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"];
    kernelModules = ["kvm-intel"];
  };
  # one entry per physical machine, in nixlab's own schema — never a raw nixos-generate-config dump
};
```
`mkHardwareProfile "<machine>"` reads this metadata directly, keyed by the machine name passed in explicitly:
```nix
# hardware/zb17g1-k3.nix
{ self, ... }: {
  flake.nixosModules.hardw--zb17g1-k3 = { ... }: {
    imports = [
      (self.lib.mkHardwareProfile "zb17g1-k3")   # explicit string — no config lookup
      self.nixosModules.hardw--profl--workstation-nvidia
    ];
  };
}
```

**`usersMeta`** — who, independent of where:
```nix
# flake/data/users-meta.nix
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

**`hostsMeta`** — where, independent of who:
```nix
# flake/data/hosts-meta.nix — mkHostMeta lives in flake/schema/hosts.nix
nixace = mkHostMeta {
  address = "10.0.0.200";
  homeUsers   = [ "temhr" ];          # gets a home-manager profile
  systemUsers = [ "temhr" "guest" ];  # gets a NixOS account
  primaryUser = "temhr";              # drives nixlab.mainUser
};
```

Generators turn metadata into config with zero per-combo files required by default:
```nix
mkHomeUsersForHost   = hostName: lib.genAttrs hostsMeta.${hostName}.homeUsers   (mkHomeUser hostName ...);
mkSystemUsersForHost = hostName: lib.genAttrs hostsMeta.${hostName}.systemUsers (mkSystemUser ...);
```
`nixlab.mainUser` is itself derived (`lib.mkDefault hostsMeta.<host>.primaryUser`), not hand-copied per host.

**Escape hatches** (real per-combo files) exist for genuine uniqueness, not as the default:
- `home/users/<username>-<hostname>.nix`, wired via `hostOverrides.<host>.extraModules`, when one user@host combo needs unique content (e.g. GPU tooling for `temhr` on `nixace`) — mirroring how sparse `hosts/nixzen.nix` and substantial `hosts/nixace.nix` coexist
- `hardwareMeta`'s per-entry `extraConfig` field, for a machine with a genuinely exotic boot requirement

### Builder Functions

Three functions turn validated metadata into real `nixosConfigurations` / `home-manager.users`. Described once here; the rest of this README just calls them by name.

| Function | Consumes | Does | Full detail |
|---|---|---|---|
| `mkHardwareProfile "<machine>"` | `hardwareMeta` | Machine name → filesystem layout + boot/initrd/kernel-module config | [Entry Point & Orchestration Files](#entry-point--orchestration-files) |
| `mkHost { name; modules; }` | `hostsMeta`, `nixlabLib`, `overlays`, `nixpkgsConfig` | Assembles the final `nixosConfiguration`: nixpkgs, sops-nix, overlays, `hostMeta`; resolves architecture/channel | [Build Flows](#build-flows) |
| `mkHomeUsersForHost` / `mkHomeUser` | `hostsMeta`, `usersMeta` | One home-manager profile per user assigned to a host, resolving per-host overrides | [Build Flows](#build-flows) |
| `mkSystemUsersForHost` / `mkSystemUser` | `hostsMeta`, `usersMeta` | One NixOS system account per user assigned to a host | [Build Flows](#build-flows) |

A username existing as a login account (`systemUsers`) and as a home-manager profile (`homeUsers`) are two independently-controlled facts, not one hardcoded assumption.

---

## Architecture & Import Flow

**File organization conventions, at a glance:**

| Folder | Contains | Rule of thumb |
|---|---|---|
| `flake/data/` | Pure attrsets, nothing else | No functions, no `mkOption` — safe to read/diff without evaluating logic |
| `flake/schema/` | Option declarations + per-axis constructors (`mkMachineMeta`, `mkHostMeta`) | Validates/default-fills `data/` attrsets — a typo'd field gets a real error, not a silent failure |
| `flake/builders/` | One file per axis (hardware, hosts, users) | Turns validated metadata into real configs — see [Builder Functions](#builder-functions) |
| `flake/ci/` | Dev-facing tooling (`checks.nix`, `apps.nix`, `packages.nix`, `observability-integration.nix`) | Plumbing for the repo, not part of what it *means* |
| `flake/nixos-lib.nix`, `flake/pkgs.nix` | Cross-cutting helpers, not axis-specific | See [Entry Point & Orchestration Files](#entry-point--orchestration-files) |

Rule of thumb: "is it data, a type/constructor, a generator, or tooling?" answers where a new file goes.

### Entry Point & Orchestration Files

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

`flake.nix` is a pure delegation layer. [flake-parts](https://github.com/hercules-ci/flake-parts) structures outputs as composable modules; [import-tree](https://github.com/vic/import-tree) auto-discovers every `.nix` file per top-level directory (see [Self-Registering Modules](#self-registering-modules)). **Paths with an `_`-prefixed segment (`_internals/`, `_tests/`, `_host-template.nix`) are skipped by import-tree**: they are never registered on their own and are only reached by relative `import` from their owning module (or, for `_tests/`, referenced by CI).

```nix
outputs = inputs @ { flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" ];     # other architectures are commented out in flake.nix
    imports = [
      (inputs.import-tree ./flake)    # → orchestration (data, schema, builders, nixos-lib, pkgs, ci)
      (inputs.import-tree ./hardware) # → hardw--* nixosModules
      (inputs.import-tree ./home)     # → home--* homeModules
      (inputs.import-tree ./hosts)    # → hosts--* nixosModules + nixosConfigurations
      (inputs.import-tree ./modules)  # → servc--*, systm--* nixosModules
      (inputs.import-tree ./stacks)   # → stack--* nixosModules (aggregators and adapters)
      (inputs.import-tree ./overlays) # → flake.overlays.*
      (inputs.import-tree ./shells)   # → perSystem.devShells.*
      (inputs.import-tree ./sops)     # → nsops--* nixosModules
    ];
  };
```

Every file under `flake/` — responsibility, output, and constraints — is covered file-by-file in [Top-Level Folder Reference → `flake/`](#flake--orchestration-metadata-constructors-generators-dev-tooling).

</details>

### Self-Registration in Practice

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Both halves of self-registration (see [Self-Registering Modules](#self-registering-modules)) look identical whether the output is a NixOS module or shared `flake.lib` data — each file assigns directly into a mergeable option, and nothing else needs to know it exists.

**Registering `nixosModules` / `nixosConfigurations`:**
```nix
# modules/nixos/dashboards/glance/default.nix
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

**Registering `flake.lib`** (metadata + generators) is the identical pattern into a different option — a `lazyAttrsOf raw` that flake-parts deep-merges. Metadata (`hostsMeta`, `usersMeta`, `hardwareMeta`), constructors (`mkHostMeta`, `mkMachineMeta`), and generators (`nixlabLib`, `mkHost`, `mkHomeUser`, ...) each live in their own self-registering file — split across `data/`, `schema/`, `builders/` by kind:
```nix
# flake/data/hosts-meta.nix — pure data, built via a schema constructor
{self, ...}: let
  inherit (self.lib) mkHostMeta;
in {
  flake.lib.hostsMeta = {
    nixace = mkHostMeta { address = "10.0.0.200"; homeUsers = ["temhr"]; systemUsers = ["temhr" "guest"]; primaryUser = "temhr"; ... };
    # ...
  };
}
```
```nix
# flake/builders/hosts.nix — consumes, never imports by path
{self, inputs, ...}: let
  hostsMeta = self.lib.hostsMeta;
  nixlabLib = self.lib.nixlabLib;
in {
  flake.lib.mkHost = { name, modules }: ...;
}
```

Because `self` resolves lazily, `builders/hosts.nix` can reference `self.lib.hostsMeta` before that attribute "arrives" from its own file — the same laziness that lets any module reference `self.nixosModules.*` regardless of load order. That's why `data/*.nix` can live anywhere without breaking the constructors or generators built on top of it.

**External flakes register the same way.** The observability flake registers its own `nixosModules` and a CI hook (`lib.observabilityHostChecks`) with the identical mechanism. nixlab consumes them by name from the input, never by path: the adapter imports `inputs.observability.nixosModules.*`, and `flake/ci/observability-integration.nix` calls `inputs.observability.lib.observabilityHostChecks` against nixlab's real hosts. nixlab does **not** re-export them as its own modules.

</details>

### Module Naming & Profile Composition

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

All NixOS modules register under `flake.nixosModules`; all home-manager modules under `flake.homeModules`. The double-dash convention encodes a two-level hierarchy in a flat namespace — cross-file references always use `self.nixosModules.*` / `self.homeModules.*`, never filesystem paths.

> **Machine name vs. hostname:** `hardw--<machine>` modules are keyed by a memorable *hardware* nickname (`zb17g1-k3`, `m720q-nas1`), deliberately **not** the same identifier space as `hostsMeta`'s hostnames (`nixace`, `nixnas1`). A `hosts--<hostname>.nix` imports whichever `hardw--<machine>` matches its physical box. Never resolve hardware facts via `config.networking.hostName` — pass the machine name explicitly (see [Three-Axis Metadata](#three-axis-metadata-hardware-hosts--users)).

| Prefix | Layer |
|--------|-------|
| `hardw--<machine>` | One file per physical machine, via `self.lib.mkHardwareProfile "<machine>"` + machine-specific mount/driver imports |
| `hardw--profl--` | Hardware profile compositions — see table below |
| `hardw--core--` | Universal hardware modules (drivers) |
| `hardw--mounts--` | Filesystem/NFS/ZFS mount modules |
| `hosts--<hostname>` | Host identity + feature selections |
| `hosts--profl--` | NixOS profile compositions — see table below |
| `hosts--core--` | Universal NixOS modules (all hosts) |
| `hosts--deskt--` | Desktop-only NixOS modules |
| `hosts--apps--` | Toggleable NixOS application modules |
| `hosts--autom--` | Scheduled tasks and automation |
| `hosts--hardw--` | Shared hardware concerns |
| `hosts--debug--` | Opt-in diagnostics (never in any profile) |
| `home--profl--` | Home-manager profile compositions — see table below |
| `home--core--` | Universal home-manager modules (every user) |
| `home--apps--` | Toggleable home-manager application modules |
| `home--shell--` | Shell/dotfile modules |
| `nsops--` | sops-nix secret wiring modules (nixlab's own; the observability flake ships its own optional `nsops--observability-*` modules, which the adapter imports) |
| `servc--` | Self-hosted service modules — atomic, no knowledge of sibling services (e.g. `servc--glance-nixlab`) |
| `stack--` | Multi-service integration bundles and external-flake adapters (`stack--observability-nixlab`; see [Top-Level Folder Reference](#top-level-folder-reference)) |
| `systm--` | Cross-cutting system defaults and small helper modules — per-service port defaults (`systm--ports-*`) and non-service helpers |

```
# nix flake show (abbreviated)
├───nixosConfigurations
│   ├───nixace, nixnas1, nixnas2, nixsun, nixtop, nixvat, nixzen
├───nixosModules
│   ├───hardw--zb17g4-p5, hardw--profl--workstation-nvidia, hosts--nixace, servc--glance-nixlab, stack--observability-nixlab, ...
├───homeModules
│   ├───home--profl--base, home--profl--desktop, home--core--config-git, home--apps--browsers, ...
```

**Profile compositions** — every `nixosConfiguration` and generated home-manager user composes from the same three-tier shape; `hardware/common/`, `hosts/common/`, `home/common/profile-*.nix` mirror each other structurally (see [The Dendritic Pattern](#the-dendritic-pattern)):

| Side | Profile | Composed of | Applies to |
|---|---|---|---|
| Hardware | *(function)* `mkHardwareProfile "<machine>"` | Universal fs layout, per-machine boot/initrd/kernel facts from `hardwareMeta`, CPU microcode | Called directly by each machine file |
| Hardware | `hardw--profl--workstation-nvidia` | nvidia driver + local `/data` mount + mirror-peer NFS mounts | The 5 nvidia-equipped workstation/laptop machines |
| NixOS | `hosts--profl--base` | Boot loader, networking, nix settings, ssh, sops, the observability adapter (`stack--observability-nixlab`) and its fleet defaults, home-manager wiring, automation timers | Every host |
| NixOS | `hosts--profl--desktop` | Dev/gaming/media/productivity/virtualization toggles, desktop-only concerns | Desktop/laptop hosts |
| NixOS | `hosts--profl--nas` | NAS-specific automation (phone media backup) | NAS hosts |
| Home-manager | `home--profl--base` | git, ssh, fastfetch, XDG folders, ephemeral-app launchers, bash shell integration | Every user |
| Home-manager | `home--profl--desktop` | Browsers, terminal emulators, virt-manager dconf tweak | Users whose resolved profile is `"desktop"` |

> `hosts--profl--base` imports the observability adapter **and** enables the stack on every host (`services.observability.enable = true`). See [Observability (external flake)](#observability-external-flake).

</details>

### Build Flows

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

**Host build flow** — `hosts/<hostname>.nix` → `nixosConfigurations.<hostname>`:
```
hosts/<hostname>.nix
  → modules = [ self.nixosModules.hardw--<machine>, hosts--<hostname>, hosts--profl--*, ... ]
       hardw--<machine> itself imports (self.lib.mkHardwareProfile "<machine>")
         → asserts hardwareMeta.<machine> exists
         → sets fileSystems/swapDevices, boot.initrd/kernelModules from hardwareMeta
  → self.lib.mkHost { name; modules; }
    → asserts hostsMeta.<hostname> exists
    → resolves nixpkgsInput (stable/unstable) + system architecture
    → injects specialArgs: nixlabLib, allHosts, hostMeta, self, inputs
    → composes: mkCommonModules ++ modules ++ [ hostName, hostId, pkgs pin, registry pin ]
    → hostLib.nixosSystem { ... }
      → flake.nixosConfigurations.<hostname>
```

**Home-manager build flow** — mirrors the host flow one layer down, per user:
```
hosts--core--home-manager-config (imported by hosts--profl--base)
  → home-manager.users = self.lib.mkHomeUsersForHost config.networking.hostName
    → for each username in hostsMeta.<hostname>.homeUsers:
      → self.lib.mkHomeUser { username; hostName; }
        → resolves usersMeta.<username>.hostOverrides.<hostName> or {} → profile, extraModules
        → imports: home--profl--base ++ (optional) home--profl--desktop ++ extraModules
        → sets home.username/homeDirectory/stateVersion, programs.git identity
```

NixOS system accounts follow the identical shape via `mkSystemUsersForHost` / `hostsMeta.<hostname>.systemUsers`, consumed by `hosts/common/core/-users.nix` — a username on a host as a login account and as a home-manager profile are two independently-controlled facts.

</details>

### Coupling Principles

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

- **Port precedence** — uses NixOS's own priority mechanism (see [Nix Ecosystem Terminology](#nix-ecosystem-terminology)) rather than convention alone, highest to lowest:
  1. **Host file** — plain assignment (`services.foo-nixlab.port = 9999;`) always wins
  2. **`modules/ports.nix`** (`systm--ports-*`) — `lib.mkDefault <value>`, the fleet-wide default for nixlab's own services
  3. **Service module's own `default`** — lowest priority, a safety net if `ports.nix` isn't imported for that service

  The observability services are the exception: their ports are the option defaults inside the observability flake (host plain assignment still wins). Stacks and adapters never set port numbers; they read the resolved values (`config.services.<x>-nixlab.port`).
- **Override contract for stacks** — a stack sets tunables with `lib.mkDefault` (a host can override via the stack's aggregator option *or* directly on the underlying service), and sets *wiring* (datasources, scrape jobs, receivers, targets) as plain additive values. Extend wiring; don't replace it.
- **Service hardening** — every `serviceConfig` routes through `nixlabLib.mkServiceHardening` rather than hand-rolled sandboxing. Exceptions override only the specific field that differs, never bypass the helper wholesale:
  ```nix
  serviceConfig = nixlabLib.mkServiceHardening {
    writablePaths    = [ cfg.dataDir ];
    allowNetwork     = true;   # default; set false for network-isolated services
    allowUnixSockets = true;   # default; set false to also forbid AF_UNIX
    allowDevices     = false;  # set true for GPU/hardware access — also relaxes
                               # ProtectKernelModules/Tunables/RestrictNamespaces
    allowJIT         = false;  # set true for JIT runtimes (Next.js, Node.js, CUDA, Alloy) —
                               # relaxes MemoryDenyWriteExecute/SystemCallFilter
    extraHardening   = false;  # set true for the extra sandbox set (empty capability set,
                               # ProtectProc=invisible, ProtectClock, UMask=0077, ...)
  } // { Type = "simple"; ExecStart = "..."; ... };
  ```
- **Durable data directories** — a service whose `dataDir` may sit on a separate mount gets a `<name>-permissions` oneshot from `nixlabLib.mkDataDirPermissionsService` (waits for the mount, then re-chowns), instead of relying on tmpfiles rules that can race the mount or miss uid drift.
- **Self-healing state** — services with a write-ahead log opt into `nixlabLib.mkWalSelfHeal` (quarantine a corrupt WAL after a crash loop, with cooldown and retention) rather than hand-written recovery.
- **External flakes are pinned inputs, reached through one adapter** — nixlab never imports another repository's files by path. A tag in `flake.nix` pins the version, one adapter module in `stacks/` translates nixlab facts into the input's public options, and the input's own CI hook runs against real hosts (see [Observability](#observability-external-flake)). Shared helpers are deliberately *not* shared: `nixlabLib` (here) and the observability flake's own `obsLib` are independent copies.
- **Single source of truth for generated aggregates** — a derived fact needed by multiple files (e.g. "which services are enabled, and what group") lives in one `_<name>-registry.nix`, imported by every consumer — never copy-pasted maps that can drift (see `modules/nixos/dashboards/homepage/_internals/service-registry.nix`; the observability adapter reads it through `self.lib.serviceRegistry` to build its TCP probe targets).

</details>

### Secrets Management

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

[sops-nix](https://github.com/Mic92/sops-nix), age-encrypted, one encrypted file per service under `sops/` (`.yaml`, or `.env` with `format = "dotenv"` when the consumer wants `KEY=VALUE` — Alertmanager). Each `nsops--<service>` module:
- `imports = [ self.nixosModules.servc--<service>-nixlab ];` — structural dependency (the secret is meaningless without the service)
- Declares `sops.secrets.<KEY> = { sopsFile = ./<service>.yaml; owner = ...; restartUnits = [...]; };` — a service may have several keys (Grafana has an admin password and a `secret_key`)
- Wires each decrypted path into the service's own options (e.g. `services.<service>-nixlab.secretsEnvFile = config.sops.secrets.<KEY>.path;`) — never reaches into `systemd.services.*` directly, never touches an unrelated option. Where the service runs as a `DynamicUser` (Alertmanager), the file stays root-owned and systemd reads it via `EnvironmentFile`.

`sops.age.keyFile` is set once, globally, in `hosts--core--sops` — never in an optional feature module, since every secret on every host depends on it.

A stack or adapter may *consume* a secret declared by an `nsops--` module it imports, but never declares secrets itself. The observability flake works the same way: its optional `nsops--observability-alertmanager` / `-grafana` modules declare `ALERTMANAGER_ENV`, `GRAFANA_ADMIN_PASSWORD` and `GRAFANA_SECRET_KEY` and wire them into the services; **the encrypted files stay in nixlab** (`sops/alertmanager.env`, `sops/grafana.yaml`) and the adapter points each module's `secretsFile` at them.

</details>

---

## Repository Reference

### Repository Layout

```
nixlab/
├── flake.nix                          # pure delegation to flake-parts + import-tree; pins `observability` by tag
├── flake.lock
├── .sops.yaml                         # sops-nix age recipient rules
│
├── flake/                             # Orchestration-level flake-parts configurations
│   ├── data/                          # pure attrsets only — no functions
│   ├── schema/                        # smart constructors (mk<axis>Meta, ...), validates attrsets
│   ├── builders/                      # generates configs (nixosConfigurations, ...) from metadata
│   ├── ci/                            # dev-facing tooling
│   │   ├── checks.nix, apps.nix, packages.nix
│   │   └── observability-integration.nix   # runs the observability flake's host checks on real hosts
│   ├── nixos-lib.nix                  # helper functions for nixlab's own modules (nixlabLib)
│   └── pkgs.nix                       # where overlays / .nixpkgsConfig are defined for pkgs
│
├── hardware/                          # Machine-level hardware configurations
│   ├── common/
│   |   ├── drivers/                   # driver-branch enum
│   |   ├── mounts/                    # local-data, nfs-mirror, zfs-raidz1-pool, ...
│   |   └── profile-*.nix, ...
│   └── <model>.nix                    # Per-device hardware configuration + module registration
│
├── hosts/                             # System-level NixOS configurations
│   ├── common/
│   |   ├── apps/                      # Toggleable software modules
│   |   ├── automation/                # Scheduled tasks (see "Deployment & Automation")
│   |   ├── core/                      # Universal modules (incl. users: users-main, users-hm, users-sys)
│   |   ├── debug/                     # diagnose.nix — opt-in only
│   |   ├── desktop/                   # Desktop-only modules
│   |   ├── hardware/                  # Physical hardware modules
│   |   └── profile-*.nix, ...
│   └── <hostname>.nix                 # nixosConfiguration + hosts--<hostname> modules
│
├── home/                              # User-level Home Manager config (home--* modules)
│   ├── common/
│   │   ├── apps/                      # Toggleable software modules
│   │   ├── core/                      # Universal modules
│   │   ├── shell/
│   │   |   └── bash.nix
│   │   └── profile-*.nix, ...
│   ├── files/bash/
│   └── users/                         # user@host extraModules
│
├── modules/                           # servc--*, systm--* — self-hosted service modules, ATOMIC only
│   ├── home-manager/                  # User-level service modules
│   ├── nixos/                         # System-level service modules
│   |   ├── ai/                        # ollama, comfyui/, hermes/
│   |   ├── dashboards/                # glance/, homepage/ (+ _internals/service-registry.nix)
│   |   ├── system/                    # wifi-hotspot, cachix
│   |   └── <service>.nix              # bookstack, home-assistant, matrix, node-red, syncthing, wiki-js, ...
│   └── ports.nix                      # systm--ports-* per-service defaults (mkDefault)
│
├── stacks/                            # stack--* — multi-service bundles and external-flake adapters
│   ├── observability-nixlab.nix       # adapter: nixlab facts → the observability flake's options
│   └── agent-infra.nix                # (see the file's own header)
│
├── sops/                              # Centralized secrets management
│   ├── <service>.nix                  # Secret module declarations (nsops--*)
│   └── <service>.yaml | .env          # Encrypted secrets per module (incl. alertmanager.env, grafana.yaml,
│                                      #   which the observability adapter wires in)
│
├── lib/                               # templates and reference material — never imported
│   ├── _host-template.nix
│   └── nixlab-module-template.md
│
├── docs/
│   ├── wiki/                          # how-to notes (e.g. nixlab-module-template.md)
│   └── migration/                     # the three guides that extracted observability into its own repo
│
├── overlays/                          # flake.overlays.*
│   └── default.nix, ...
│
├── shells/                            # perSystem.devShells.*
│   └── default-shell.nix, ...
│
├── cachix/                            # per-cache substituter config
├── pkgs/                              # perSystem.packages
└── bin/                               # standalone utility scripts, not flake outputs
```

### Top-Level Folder Reference

Every top-level folder answers one question: *what kind of thing does a file in here become?* Check the file requirements below before adding anything new — that's what keeps the [self-registering](#self-registering-modules) architecture from turning into "put it wherever seems fine."

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

### `flake/` — orchestration: metadata, constructors, generators, dev tooling

Every other folder depends on `flake/`; `flake/` depends on nothing else — it's the foundation, organized by *kind of thing* rather than *feature*. (CI files in `flake/ci/` are the one exception in spirit: they consume named `self.lib.*` hooks and `self.nixosConfigurations` for validation, never by path.)

| File | Responsibility | Output | Must |
|---|---|---|---|
| `data/hardware-meta.nix` | Per-machine hardware facts in nixlab's own schema (not raw `nixos-generate-config`): `cpuVendor`, `initrdAvailableKernelModules`, `initrdKernelModules`, `kernelModules`, `extraModulePackages`, `extraConfig` escape hatch — built via `mkMachineMeta` | `flake.lib.hardwareMeta` | Only `schema/` constructor calls or literals — never reference `config`, never define a module |
| `data/hosts-meta.nix` | Per-host metadata: IPs, interfaces, architecture, nixpkgs input, `homeUsers`, `systemUsers`, `primaryUser` — built via `mkHostMeta` | `flake.lib.hostsMeta` | Same as above |
| `data/users-meta.nix` | Per-user identity: git name/email, default profile, per-host overrides, SSH keys, NixOS account facts | `flake.lib.usersMeta` | Same as above |
| `schema/options.nix` | Declares `flake.lib` / `flake.homeModules` as mergeable `lazyAttrsOf` options — makes self-registration possible repo-wide | *(option declarations only)* | Export exactly one constructor (or option-decl file) per axis |
| `schema/hardware.nix` | `mkMachineMeta`, consumed by `data/hardware-meta.nix` | `flake.lib.mkMachineMeta` | A typo'd field must error, never silently `null` |
| `schema/hosts.nix` | `mkHostMeta` incl. `interfaces` derivation (ethernet + optional wifi) and `gateway`/`nameservers`, consumed by `data/hosts-meta.nix` | `flake.lib.mkHostMeta` | Same as above |
| `builders/hardware.nix` | `mkHardwareProfile` — reads `self.lib.hardwareMeta`, machine name → fs layout + boot/initrd/kernel config | `flake.lib.mkHardwareProfile` | Consume `self.lib.<axis>Meta` only — never import another `flake/` file by path |
| `builders/hosts.nix` | `mkHost` + `mkCommonModules` — reads `hostsMeta`/`nixlabLib`/`overlays`/`nixpkgsConfig`, injects nixpkgs, sops-nix, overlays, `hostMeta` | `flake.lib.mkHost` | Same as above |
| `builders/users.nix` | `mkHomeUser`, `mkHomeUsersForHost`, `mkSystemUser`, `mkSystemUsersForHost` — reads `hostsMeta`/`usersMeta` | `flake.lib.mkHomeUser`, `.mkHomeUsersForHost`, `.mkSystemUser`, `.mkSystemUsersForHost` | Same as above |
| `nixos-lib.nix` | Shared helpers injected as `nixlabLib` via `specialArgs`: `mkNginxVirtualHost`, `mkFirewallPorts`, `mkServiceHardening`, `mkSslAssertion`, `mkDataDirPermissionsService`, `mkWalSelfHeal` — for nixlab's own modules (the observability flake keeps an independent `obsLib`) | `flake.lib.nixlabLib` | Stay cross-cutting — a single-service function belongs in that service's module |
| `pkgs.nix` | Source of truth for `overlays` and `nixpkgsConfig` (`allowUnfree`, `nvidia.acceptLicense`), consumed by `perSystem` pkgs *and* every per-host pkgs set | `flake.lib.overlays`, `.nixpkgsConfig`, `perSystem._module.args.pkgs` | Never duplicated elsewhere |
| `ci/checks.nix` | Pre-commit hooks (alejandra, deadnix, merge-conflict guards) + formatter | `perSystem.checks`, `flake.formatter` | Never referenced by host/user/machine config — repo plumbing only |
| `ci/apps.nix` | `build-all` app — validates every `nixosConfiguration` | `perSystem.apps.build-all` | Same as above |
| `ci/packages.nix` | Imports `pkgs/` into perSystem | `perSystem.packages` | Same as above |
| `ci/observability-integration.nix` | Runs the observability flake's own host checks (`promtool`/`amtool` on the rendered configs, rule tests, runbook coverage…) against nixlab's **real** hosts, one per nixpkgs channel (`nixnas1` stable, `nixsun` unstable) | `perSystem.checks` (x86_64-linux) | Consume `inputs.observability.lib.observabilityHostChecks` by name; same "plumbing only" rule |

### `hardware/` — physical machine facts

Boot/initrd/kernel-module facts and fs layout belong to a physical box, independent of hostname or users (see [Three-Axis Metadata](#three-axis-metadata-hardware-hosts--users)).

- **One file per machine** (`hardware/<machine>.nix`) — must call `(self.lib.mkHardwareProfile "<machine>")` with the file's own machine name, plus whichever `hardw--profl--*`/`hardw--mounts--*` modules it needs. Never looks up identity via `config.networking.hostName`.
- **`common/drivers/`, `common/mounts/`** — atomic, reusable across machines. Mount modules take pool name/peer list/device paths as options — never hardcode a machine's nickname.
- **`common/profile-*.nix`** — composes drivers/mounts into a named hardware role (e.g. `workstation-nvidia`), imported by multiple machine files.

### `hosts/` — NixOS system identity & composition

Where a physical/logical machine becomes a bootable `nixosConfiguration` — host identity, profile selection, genuinely unique per-host config.

- **`hosts/<hostname>.nix`** — must call `self.lib.mkHost { name; modules; }`. The `hosts--<hostname>` module holds only feature toggles and truly host-unique config — never `nixlab.mainUser` or home-manager user lists (both derived from `hostsMeta`).
- **`common/core/`** — universal, non-toggleable, imported by every host via `hosts--profl--base`. Optional content belongs in `apps/` with a real `enable` option instead.
- **`common/apps/`, `common/desktop/`, `common/automation/`, `common/hardware/`** — toggleable/role-scoped modules with `lib.mkEnableOption`-style options, composed into profiles rather than imported directly.
- **`common/debug/`** — opt-in diagnostics only; never in any `profile-*.nix`.
- **`lib/_host-template.nix`** (top-level `lib/`) — reference only, never imported (`lib/` is not in the import-tree list).

### `home/` — home-manager user identity & composition

Mirrors `hosts/` one layer down — per-user, session-scoped instead of per-host, system-scoped.

- **`common/core/`** — universal, imported by every user via `home--profl--base`. Same "unconditional or it doesn't belong" rule.
- **`common/apps/`** — toggleable per-user preferences (browsers, terminals). A feature needing a system daemon (e.g. `virtualisation.libvirtd`) belongs in `hosts/`; only the per-user layer goes here.
- **`common/shell/`** — dotfile/shell-integration modules; reads directory contents (`builtins.readDir`) rather than hand-listing files where the set can grow (see `bash.nix`'s alias loading).
- **`users/`** — the per-combo escape hatch (see [Three-Axis Metadata](#three-axis-metadata-hardware-hosts--users)), wired via `hostOverrides.<host>.extraModules`.

### `modules/` — atomic service modules

The "one service, one file/directory, zero knowledge of any other service" tier — the most restrictive folder in the repo.

**Belongs in `modules/nixos/<service>/` only if all of:**
1. Declares `options.services.<service>-nixlab.*` and nothing outside that namespace (beyond the user/group/unit it owns)
2. `config` never sets an option under a *different* service's namespace (e.g. `servc--home-assistant-nixlab` must never set `services.node-red-nixlab.*`) — that's the signal to move to `stacks/`
3. `serviceConfig` is built from `nixlabLib.mkServiceHardening`, deviations via a named flag (`allowJIT`, `allowDevices`, `extraHardening`) — see [Coupling Principles](#coupling-principles)
4. Provides its own escape-hatch options (`extraConfig`-style attrsets, lists of extra targets, …) for anything `stacks/` might inject, rather than a stack reaching into `systemd.services.*` directly

`ports.nix` is the one exception at this folder's root — genuinely cross-cutting (default ports for every service) rather than belonging to one service.

`systm--` modules are *helper* modules rather than services: they obey rules 1, 2 and 4 but don't run a daemon of their own.

Monitoring is **not** in this folder any more: the Prometheus/Loki/Grafana/Alertmanager/ntfy/Alloy modules live in the observability flake (see [Observability](#observability-external-flake)).

### `stacks/` — multi-service bundles and external-flake adapters

Some services must communicate to work well together. That wiring can't live inside any one service module without giving it illegitimate knowledge of its siblings — `stacks/` is where it goes instead. The same reasoning covers an **external flake**: its modules know nothing of nixlab, so something must translate nixlab's facts into its options.

**A stack belongs in `stacks/` (named `stack--<n>`) only if:**
1. Imports **two or more** `servc--`/`nsops--` modules (`systm--` helper modules may also be imported)
2. Sets at least one option belonging to a service *other than* the one it's adjacent to in the import list — real cross-wiring, not just co-importing
3. Implements **no service logic of its own** — no `systemd.services.*`, no `users.users.*`; only sets options the underlying modules already declared
4. Exposes its own aggregator option so a host consumes one coherent interface

**An adapter** (`stack--<n>-nixlab`, today `observability-nixlab.nix`) follows rules 3 and 4 in spirit and adds its own:
1. It is the **only** file in nixlab that imports the external flake's modules (`inputs.<flake>.nixosModules.*`)
2. It only *translates*: host metadata, the service registry, `nixlab.mainUser` and the encrypted file paths become the flake's public options. No service logic, no duplicated wiring
3. Values that used to be an option default use `lib.mkDefault`; list options that must merge (`extraUsers`) are assigned plainly, because a `mkDefault` list is silently dropped as soon as a host sets its own
4. Fleet policy (what to enable, retention, exposure) stays in the **profiles**, not the adapter

If a candidate satisfies stack rule #1 but not #2 — e.g. ComfyUI's three cooperating modules, which all target the *same* service's namespace — it stays in `modules/`. The test: do two *different* services' option surfaces get touched, not do multiple files work together.

### `sops/` — secrets

Secret material must never enter the Nix store; sops-nix decrypts at activation. The wiring from encrypted file to service option needs its own home, separate from both the service module and the secret content.

- **One `.nix` + one encrypted file (`.yaml`, or `.env` for dotenv format) per service**, named identically to the service (see [Secrets Management](#secrets-management)): imports the service module, declares `sops.secrets.*`, wires each decrypted path into an option the service already declared.
- Global settings (`sops.age.keyFile`) belong in `hosts/common/core/`, never in an optional `sops/*.nix` module.

### `docs/`

- **`docs/wiki/`** — how-to notes (for example `nixlab-module-template.md`, the template for a new service module).
- **`docs/migration/`** — the three step-by-step guides (`obs-01-…`, `obs-02-…`, `obs-03-…`) that extracted the observability stack into its own repository, kept as the record of how and why. Monitoring documentation itself (architecture, options reference, alert runbooks) lives in the [observability repo](https://github.com/Temhr/observability).

### `overlays/`, `shells/`, `cachix/`, `pkgs/`, `lib/`, `bin/`

Self-contained, single-purpose flake outputs with no cross-folder dependencies and no shared naming convention.

- **`overlays/`** — one file per overlay (`final: prev: {...}`), registered in `flake.overlays.*` via `default.nix`
- **`shells/`** — one file per `devShell`, registered in `perSystem.devShells.*`
- **`cachix/`** — one file per binary cache substituter
- **`pkgs/`** — custom package derivations, registered in `perSystem.packages` via `default.nix`
- **`lib/`** — templates and reference material (`_host-template.nix`, `nixlab-module-template.md`); not in the import-tree list, so nothing here is ever evaluated.
- **`bin/`** — scripts run directly by a human, never referenced by any Nix module (today: `repast-bs.sh`, `home-directory-organizer-script.sh`, `sum-cat.sh`). If a script needs to be *part of* config (installed as a package, run by a systemd unit), it belongs in the relevant service module instead. The monitoring helper scripts now ship with the observability flake (`nix run …#mon-check`).

</details>

---

## Observability (external flake)

<details open>
<summary><i>(click to collapse)</i></summary>
<p></p>

Monitoring — Prometheus, Alertmanager, ntfy, Loki, Alloy, Grafana, exporters, a maintenance log, ~60 alerts with runbooks — is **not part of this repository**. It is its own flake, **[Temhr/observability](https://github.com/Temhr/observability)**, consumed as a **pinned input** (`inputs.observability`, a release tag in `flake.nix`). Its architecture, generated options reference, public API and alert runbooks are documented there; this section covers only how nixlab *uses* it.

```
 observability flake                        nixlab
 ───────────────────                        ──────────────────────────────────────────
 stack--observability (aggregator)  ◄──────  stacks/observability-nixlab.nix   (adapter: facts → options)
 servc--observability-* services             hosts/common/profile-{base,desktop,nas}.nix (fleet policy)
 nsops--observability-* (optional)  ◄──────  sops/alertmanager.env, sops/grafana.yaml   (encrypted files)
 lib.observabilityHostChecks        ◄──────  flake/ci/observability-integration.nix     (CI on real hosts)
```

**The adapter** (`stacks/observability-nixlab.nix`, module `stack--observability-nixlab`, imported by `hosts--profl--base`) only translates:

| nixlab fact | Becomes |
|---|---|
| `hostMeta.address`, `hostMeta.gateway` | `services.observability.publicHost`, `probes.gateway` (`mkDefault`) |
| the homepage service registry (`self.lib.serviceRegistry`) | `probes.tcpTargets` — a TCP probe for every service enabled on the host |
| `sops/alertmanager.env`, `sops/grafana.yaml` | `secretsFile` of the imported `nsops--observability-alertmanager` / `-grafana` modules |
| `nixlab.mainUser` | `extraUsers` on the loki, grafana, alloy, ntfy and prometheus services (read access to their data) |
| behaviour nixlab relied on before the extraction | `integrations.nvidia.enable` (Xid log alert), `…maintenance.alerts.features.zfsMembers` (ZFS member/scrub alerts), `…grafana.timersRegex` (the timers shown on the dashboard) |

**Fleet policy lives in the profiles**, not the adapter:
```nix
# hosts/common/profile-base.nix — every host
services.observability = {
  enable = true;
  openFirewall = false;
  dataDir = "/data";
  access.expose = [ "grafana" "ntfy" "prometheus" ];   # which services may leave loopback…
  notifications.ntfyAuth.enable = false;
  notifications.topics.storage.matchers = [ ''category=~"storage|backup"'' ];
  loki = { maintenance.enable = true; retention = "168h"; };   # the maintenance log keeps 2 years regardless
  prometheus = {
    maintenance.enable = true;                          # full alert set + exporters
    maintenance.exporters.smartctl.enable = true;
    scrapeInterval = "60s"; retention = "7d"; retentionSize = "4GB";
  };
};
```
```nix
# hosts/common/profile-desktop.nix — nixace, nixsun, nixtop, nixvat, nixzen
services.observability-prometheus.maintenance.expectedMounts = [ "/data" ];
services.observability.access.interfaces = [ hostMeta.ethIface hostMeta.wifiIface ];   # …and on which interfaces

# hosts/common/profile-nas.nix — nixnas1, nixnas2
services.observability-prometheus.maintenance.expectedMounts = [ "/mirror" ];
services.observability.access.interfaces = [ hostMeta.ethIface ];                       # wired only
```
Services bind loopback unless they are in `access.expose` **and** an interface is named in `access.interfaces`; the firewall is then opened per interface. Profile values are plain assignments, so a host that sets the same option needs `lib.mkForce`.

**Per-host overrides**
```nix
services.observability.prometheus.retentionSize = lib.mkForce "20GB";
services.observability-grafana.extraDashboards = [ "zfs-monitoring" ];   # ZFS host only
```

**Operating it** (run on the host)
```bash
nix run github:Temhr/observability/<pinned-tag>#mon-check                  # units, endpoints, scrape targets, rules, Alertmanager link, Loki
nix run github:Temhr/observability/<pinned-tag>#mon-check -- --fire-test  # end-to-end: alert → Alertmanager → ntfy
                                                                           # (needs MON_NTFY_AUTH=reader:<pw> only when ntfy auth is on)
nix run github:Temhr/observability/<pinned-tag>#mon-snapshot -- /tmp/before   # diff before vs after a change
sudo maintenance-log --section II.4 --task "Applied updates" --status completed
nix flake check                                                            # includes the observability integration checks
```
`<pinned-tag>` is the tag in `flake.nix`'s `inputs.observability.url`.

**Upgrading it**
1. Read the observability `CHANGELOG.md` for the new tag (breaking changes and deprecations are listed there; deprecated option/module names keep working for one minor release and warn).
2. Change the tag in `flake.nix`, then `nix flake update observability`.
3. `nix flake check`, then `nix run .#build-all`.
4. Deploy to **one** host first (see [Deployment & Automation](#deployment--automation) for how to keep your own timers from interfering), run `mon-check`, soak, then merge.

**Adding things.** A host-specific scrape target: `services.observability-prometheus.extraScrapeConfigs`. A receiver: `services.observability-alertmanager.receivers`. A new alert, dashboard or runbook that is generally useful belongs **upstream** (see that repo's `docs/development/extending.md`), not in nixlab.

**Where it came from.** The stack used to live in this repo (`modules/nixos/observability/`, `stacks/observability.nix`); `docs/migration/` records the extraction, the decoupling from nixlab's metadata, and the renames.

</details>

---

## Deployment & Automation

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Hosts converge from GitHub on timers (`hosts/common/automation/`, all imported by `hosts--profl--base`, so **every host runs all three**):

| Module | Schedule | What it does |
|---|---|---|
| `hosts--autom--nixos-upgrade` | 02:00 + up to 30 min | `system.autoUpgrade` from **`github:Temhr/nixlab`** (i.e. `main`), `operation = "boot"`, **`allowReboot = true`**, `--no-write-lock-file` |
| `hosts--autom--flake-update` | 23:40 + up to 1 h | in `~/nixlab`: `git pull --rebase`, **`nix flake update` (all inputs)**, commit `flake.lock` if it changed, `git push` |
| `hosts--autom--nixlab-gpull` | hourly (1 min after boot) | `git pull --rebase` in `~/nixlab` |

What follows from that:
- **Merging to `main` rolls out to every host the same night, with a reboot.** Plan for it; there is no staged rollout unless you create one.
- **A pinned tag survives `nix flake update`** (it re-resolves the same tag). A lock edited with `--override-input` does **not**: change the `url` in `flake.nix` instead.
- **Never leave a feature branch checked out in a host's `~/nixlab`.** The timers will rebase it, update every input on it, and try to push.
- **To try a branch on one host**, use a separate checkout and stop the timers for that host in the branch, otherwise the 02:00 upgrade puts `main` back:
  ```bash
  git clone git@github.com:Temhr/nixlab.git ~/nixlab-canary && cd ~/nixlab-canary && git switch <branch>
  sudo nixos-rebuild switch --flake ~/nixlab-canary#<hostname>
  ```
  ```nix
  # hosts/<hostname>.nix, on the branch only — remove before merging
  system.autoUpgrade.enable = lib.mkForce false;
  systemd.timers.flake-update.enable = lib.mkForce false;
  systemd.timers.nixlab-gpull.enable = lib.mkForce false;
  ```
- **Comparing two builds across midnight** also compares whatever `flake-update` pushed in between (nixpkgs moves). For parity checks, evaluate both sides from the same commit's lock.

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

nix flake check          # eval + pre-commit checks + observability integration checks (the flake's own host checks on nixnas1 / nixsun)
nix run .#build-all      # build every nixosConfiguration without switching
nix fmt                  # run alejandra across the whole tree

nix run github:Temhr/observability/<pinned-tag>#mon-check   # monitoring health on the current host (see Observability)
```

</details>

- ### <ins>Adding a New Host</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

A "host" (network identity, users, services — `hostsMeta`) and a "machine" (physical hardware — `hardwareMeta`) are independent concerns (see [Three-Axis Metadata](#three-axis-metadata-hardware-hosts--users)); a new physical box needs both, and an existing machine can be reinstalled under a new hostname without redoing its hardware facts.

#### 1. Capture the machine's hardware facts once, add to `flake/data/hardware-meta.nix`

Boot the installer on the physical machine and run (non-destructive):
```bash
nixos-generate-config --show-hardware-config
```
Transcribe only genuinely machine-specific facts — everything else is either a fleet-wide default or already standardized by partition labels:
```nix
# flake/data/hardware-meta.nix — mkMachineMeta is declared in flake/schema/hardware.nix
<machine> = mkMachineMeta {
  cpuVendor = "intel";                              # or "amd"
  initrdAvailableKernelModules = [ "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  kernelModules = [ "kvm-intel" ];                   # or [ "kvm-amd" ]
  # initrdKernelModules / extraModulePackages — only if the generator output listed any
  # extraConfig = { ... };                          # escape hatch for a genuinely exotic fact
};
```

#### 2. Create the machine module `hardware/<machine>.nix`

No raw `hardware-configuration.nix` is pasted anywhere — `mkHardwareProfile` reads the metadata above, keyed by the explicit string passed in:
```nix
{ self, ... }: {
  flake.nixosModules.hardw--<machine> = { ... }: {
    imports = [
      (self.lib.mkHardwareProfile "<machine>")        # universal fs layout + this machine's boot facts
      self.nixosModules.hardw--profl--workstation-nvidia  # if it has an nvidia GPU
      # self.nixosModules.hardw--mounts--local-data       # if it needs /data
      # self.nixosModules.hardw--mounts--mirror-peer      # if it mirrors NAS peers
    ];
    # driver-nvidia.driver-branch = "l580";  # only if it needs to differ from the
                                              # workstation-nvidia profile's mkDefault "l470"
  };
}
```

#### 3. Add host metadata to `flake/data/hosts-meta.nix`

```nix
<hostname> = mkHostMeta {
  address = "10.0.0.XXX";
  ethIface = "enp0s31f6";            # Find with: ip link
  wifiIface = "wlp3s0";              # Find with: ip link (omit or "" if no wifi)
  hostId = "XXXXXXXX";               # Generate with: head -c 8 /etc/machine-id
  nixpkgsInput = "nixpkgs-stable";   # or "nixpkgs-unstable"
  homeUsers = [ "temhr" ];           # usernames that get a home-manager profile here
  systemUsers = [ "temhr" "guest" ]; # usernames that get a NixOS account here
  primaryUser = "temhr";            # drives nixlab.mainUser automatically
};
```

#### 4. Create host configuration `hosts/<hostname>.nix`

```nix
{ self, ... }: {
  flake.nixosConfigurations.<hostname> = self.lib.mkHost {
    name = "<hostname>";
    modules = [
      self.nixosModules.hardw--<machine>        # note: machine name, not hostname
      self.nixosModules.hosts--<hostname>
      self.nixosModules.hosts--profl--base      # required for all hosts (includes the observability adapter; monitoring is on by default)
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

    # monitoring is already enabled by hosts--profl--base; tune it with services.observability.* (see "Observability")

    system.stateVersion = "24.11";
  };
}
```

#### 5. Deploy

```bash
cd ~/nixlab
git add -A            # new/untracked files are invisible to the flake until staged
nix flake check
nix eval .#nixosConfigurations.<hostname>.config.boot.initrd.availableKernelModules --json
# ^ confirm this matches the machine's own captured facts from Step 1, not another
#   machine's — this is the correctness check that matters most on first deploy
sudo nixos-rebuild switch --flake .#<hostname>
```

</details>

- ### <ins>Adding a New Home User</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Home-manager users are **generated**, not hand-written per host (see [Builder Functions](#builder-functions)). Adding a user, or an existing user to a new host, is a metadata change only.

#### 1. Add the user's identity to `flake/data/users-meta.nix`

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

#### 2. Add the username to the target host(s) in `flake/data/hosts-meta.nix`

```nix
nixsun = mkHostMeta {
  ...
  homeUsers = [ "guest" "rhmet" ];
  systemUsers = [ "guest" "rhmet" ];
};
```

`mkHomeUsersForHost` and `mkSystemUsersForHost` generate both the home-manager profile and the NixOS account automatically on the next rebuild.

#### 3. (Only if genuinely needed) Add a per-combo extra module

If one user@host combination needs unique content beyond the shared profile (e.g. GPU tooling for one machine), create a real file and wire it through `hostOverrides`:

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
# flake/data/users-meta.nix
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

Service modules live in `modules/nixos/<service>/` (see [Top-Level Folder Reference](#top-level-folder-reference) for what belongs here). Secrets are managed separately in `sops/`.

> Shared helpers (`mkNginxVirtualHost`, `mkFirewallPorts`, `mkServiceHardening`, `mkSslAssertion`, `mkDataDirPermissionsService`, `mkWalSelfHeal`) are available in any module via `{ nixlabLib, ... }:` — see `flake/nixos-lib.nix`, and [Coupling Principles](#coupling-principles) for `mkServiceHardening`'s flags. A starting template is in `docs/wiki/nixlab-module-template.md`.

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

#### 4. (Optional) Make it observable

Expose `/metrics` and add a scrape job on the host with `services.observability-prometheus.extraScrapeConfigs` (a TCP probe for the service port is added automatically through the service registry). An alert or dashboard that is generally useful is contributed **upstream** to the observability repo (alert + runbook + rule test; see its `docs/development/extending.md`), then picked up by bumping the pinned tag.

#### 5. Validate and deploy

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
        # format = "dotenv";   # when the file is KEY=VALUE lines (see sops/alertmanager.nix)
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
