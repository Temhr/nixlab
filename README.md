# nixlab

Modular NixOS configuration for Linux laptops, desktops, and homelab servers. Built on the **Dendritic Pattern** using **flake-parts** for composable, self-registering modules where every file declares its own outputs — including its own metadata and library functions.

Adapted from [Misterio77's nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) with inspiration from [EmergentMind](https://www.youtube.com/watch?v=YHm7e3f87iY&list=PLAWyx2BxU4OyERRTbzNAaRHK08DQ0DD_l&index=1), [Vimjoyer](https://www.youtube.com/@vimjoyer), and the broader NixOS community. Rewritten, and rewritten, and rewritten again, almost entirely by Claude.

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
  - [Three-Axis Metadata: Hardware, Hosts & Users](#three-axis-metadata-hardware-hosts--users)
  - [Profile Composition](#profile-composition)
  - [Host Build Flow](#host-build-flow)
  - [Home-Manager Build Flow](#home-manager-build-flow)
  - [Coupling Principles](#coupling-principles)
  - [Secrets Management](#secrets-management)
- [Repository Layout](#repository-layout)
- [Top-Level Folder Reference](#top-level-folder-reference)
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

**File organization conventions, at a glance:**
- **`flake/data/`** — pure attrsets, nothing else. No functions, no `mkOption` calls. Safe to read (or diff, or hand to a non-Nix script) without evaluating any logic.
- **`flake/schema/`** — option declarations and per-axis smart constructors (`mkMachineMeta`, `mkHostMeta`) that validate and default-fill the attrsets in `data/`. This is where a typo'd field name or wrong type gets caught, with a real error message, instead of failing silently three files later.
- **`flake/builders/`** — one file per independent axis (hardware, hosts, users), each turning validated metadata into real `nixosConfigurations` / `home-manager.users`. If it *generates* NixOS or home-manager config from metadata, it lives here.
- **`flake/ci/`** — dev-facing tooling (`checks.nix`, `apps.nix`, `packages.nix`). This is plumbing for working on the repo, not part of what the repo *means*.
- **`flake/nixos-lib.nix`** and **`flake/pkgs.nix`** sit outside all four folders because they're cross-cutting rather than axis-specific: `nixos-lib.nix` is helper functions any service module can use, and `pkgs.nix` is the one place `overlays`/`nixpkgsConfig` are defined for every `pkgs` set the flake builds.

The short version: if you're asking "where does this go?", ask "is it data, a type/constructor, a generator, or tooling?" — that answers it.

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
      (inputs.import-tree ./flake)    # → orchestration (data, schema, builders, nixos-lib, pkgs, ci)
      (inputs.import-tree ./hardware) # → hardw--* nixosModules
      (inputs.import-tree ./home)     # → home--* homeModules
      (inputs.import-tree ./hosts)    # → hosts--* nixosModules + nixosConfigurations
      (inputs.import-tree ./modules)  # → servc--*, systm--* nixosModules
      (inputs.import-tree ./stacks)   # → stack--* nixosModules
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

A small number of concerns live in `flake/` as conventional flake-parts files, organized by *kind of thing* rather than lumped into one folder: `data/` (pure metadata, no functions), `schema/` (types + smart constructors for that data), `builders/` (one file per independent axis that turns metadata into real config), and `ci/` (dev tooling, not repo "meaning"). All of them, including metadata and shared functions, are self-registering — none are imported by hardcoded relative path.

| File | Responsibility | Output |
|------|---------------|--------|
| `flake/data/hardware-meta.nix` | Per-machine hardware facts, in nixlab's own schema rather than raw `nixos-generate-config` output: `cpuVendor`, `initrdAvailableKernelModules`, `initrdKernelModules`, `kernelModules`, `extraModulePackages`, an `extraConfig` escape hatch — a pure attrset, built via `mkMachineMeta` | `flake.lib.hardwareMeta` |
| `flake/data/hosts-meta.nix` | Per-host metadata: IPs, interfaces, architecture, nixpkgs input selection, `homeUsers`, `systemUsers`, `primaryUser` — a pure attrset, built via `mkHostMeta` | `flake.lib.hostsMeta` |
| `flake/data/users-meta.nix` | Per-user identity: git name/email, default home-manager profile, per-host overrides, SSH authorized keys, NixOS account facts (`isNormalUser`, `extraGroups`, `initialPassword`) | `flake.lib.usersMeta` |
| `flake/schema/options.nix` | Declares `flake.lib` and `flake.homeModules` as mergeable `lazyAttrsOf` options — the option declarations that make self-registration possible across the whole repo | *(option declarations only)* |
| `flake/schema/hardware.nix` | `mkMachineMeta` — the smart constructor consumed by `data/hardware-meta.nix` | `flake.lib.mkMachineMeta` |
| `flake/schema/hosts.nix` | `mkHostMeta`, including the `interfaces` list derivation (ethernet + optional wifi) — consumed by `data/hosts-meta.nix` | `flake.lib.mkHostMeta` |
| `flake/builders/hardware.nix` | `mkHardwareProfile` — reads `self.lib.hardwareMeta`, turns a machine name into filesystem layout + boot/initrd/kernel-module config | `flake.lib.mkHardwareProfile` |
| `flake/builders/hosts.nix` | `mkHost` + `mkCommonModules` — reads `self.lib.hostsMeta` / `self.lib.nixlabLib` / `self.lib.overlays` / `self.lib.nixpkgsConfig`, injects nixpkgs, sops-nix, overlays, and `hostMeta` into every host | `flake.lib.mkHost` |
| `flake/builders/users.nix` | `mkHomeUser`, `mkHomeUsersForHost`, `mkSystemUser`, `mkSystemUsersForHost` — reads `self.lib.hostsMeta` / `self.lib.usersMeta` | `flake.lib.mkHomeUser`, `.mkHomeUsersForHost`, `.mkSystemUser`, `.mkSystemUsersForHost` |
| `flake/nixos-lib.nix` | Shared NixOS helper functions (`mkNginxVirtualHost`, `mkFirewallPorts`, `mkServiceHardening`, `mkSslAssertion`) injected into every module as `nixlabLib` via `specialArgs` — cross-cutting, not tied to any one axis | `flake.lib.nixlabLib` |
| `flake/pkgs.nix` | Single source of truth for `flake.lib.overlays` and `flake.lib.nixpkgsConfig` (`allowUnfree` + `nvidia.acceptLicense`), consumed by both `perSystem` pkgs *and* every per-host pkgs set in `builders/hosts.nix` — closes what used to be a hand-copied duplication between the two | `flake.lib.overlays`, `.nixpkgsConfig`, `perSystem._module.args.pkgs` |
| `flake/ci/checks.nix` | Pre-commit hooks (alejandra, deadnix, merge-conflict guards) + formatter | `perSystem.checks`, `flake.formatter` |
| `flake/ci/apps.nix` | `build-all` app — validates every `nixosConfiguration` | `perSystem.apps.build-all` |
| `flake/ci/packages.nix` | Imports `pkgs/` into perSystem | `perSystem.packages` |

</details>

- ### <ins>The Dendritic Pattern</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Instead of configuring each machine individually, you assemble it from capabilities. **Features** > **Profiles** > **Hosts** — branching from general to specific: _"which features does this machine require?"_ This applies identically on both the NixOS side and the home-manager side.

1. **Feature Modules** — standalone services (`modules/`), secrets (`sops/`), or modules domain-grouped by shared behaviour
    - `hosts/common/` — `core/`, `desktop/`, `apps/`, `automation/`, `hardware/`
    - `home/common/` — `core/`, `apps/`, `shell/`
1. **Stacks** — `stacks/` composes ≥2 atomic service modules that must communicate (cross-service wiring: datasource provisioning, scrape targets, alert routing) into one working system, exposing a single aggregator option surface. Only warranted when integration logic would otherwise pollute an atomic service module with knowledge of its siblings — see [Top-Level Folder Reference](#top-level-folder-reference)
1. **Profiles** — (`profile-base`, `profile-desktop`, `profile-nas`) composed from **Feature Modules** and **Stacks** into role-appropriate bundles, mirrored identically in `hosts/common/` and `home/common/`
1. **Host / User manifest** — metadata entries in `flake/data/hosts-meta.nix` / `flake/data/users-meta.nix` selecting profiles, plus a thin per-host file for genuinely unique feature selections
1. **`nixosConfigurations.<hostname>`** and **`home-manager.users.<username>`** — fully built outputs, generated by `mkHost` (`flake/builders/hosts.nix`) / `mkHomeUsersForHost` (`flake/builders/users.nix`), with overlays, secrets, and cross-host metadata wired in automatically

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

`flake.lib` works exactly like `flake.nixosModules`/`flake.homeModules`: it's a declared `lazyAttrsOf raw` option (in `flake/schema/options.nix`) that flake-parts deep-merges across every file that contributes to it. This means shared metadata (`hostsMeta`, `usersMeta`, `hardwareMeta`), the constructors that build it (`mkHostMeta`, `mkMachineMeta`), and the generators that consume it (`nixlabLib`, `mkHost`, `mkHomeUser`, ...) can each live in their own self-registering file — split across `data/`, `schema/`, and `builders/` by kind — with no file needing to know where another lives or import it by relative path.

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

Because `self` is resolved lazily by flake-parts, `builders/hosts.nix` can reference `self.lib.hostsMeta` before that attribute has "arrived" from its own file — the same laziness trick that already lets any module reference `self.nixosModules.*` regardless of load order. This is why the metadata files (`data/hosts-meta.nix`, `data/users-meta.nix`) can live anywhere in the tree without breaking anything that consumes them — including the `schema/*.nix` constructors they're built from, and the `builders/*.nix` generators that consume them in turn.

</details>

- ### <ins>Module Namespace & Naming</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

All NixOS modules register under `flake.nixosModules`; all home-manager modules register under `flake.homeModules`. The double-dash convention encodes a two-level hierarchy in a flat namespace — all cross-file references use `self.nixosModules.*` / `self.homeModules.*`, never filesystem paths.

> **Machine name vs. hostname:** `hardw--<machine>` modules are keyed by a memorable *hardware* nickname (`zb17g1-k3`, `m720q-nas1`) loosely based on model/manufacturer — deliberately **not** the same identifier space as `hostsMeta`'s hostnames (`nixace`, `nixnas1`). A `hosts--<hostname>.nix` file imports whichever `hardw--<machine>` module matches the physical box it runs on. Never look up hardware facts through `config.networking.hostName` — pass the machine name explicitly (see [Three-Axis Metadata](#three-axis-metadata-hardware-hosts--users)).

| Prefix | Layer |
|--------|-------|
| `hardw--<machine>` | One file per physical machine, built via `self.lib.mkHardwareProfile "<machine>"` + machine-specific mount/driver imports |
| `hardw--profl--` | Hardware profile compositions (workstation-nvidia, etc.) |
| `hardw--core--` | Universal hardware modules (drivers) |
| `hardw--mounts--` | Filesystem/NFS/ZFS mount modules |
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
| `servc--` | Self-hosted service modules — atomic, no knowledge of sibling services |
| `stack--` | Multi-service integration bundles — imports ≥2 `servc--`/`nsops--` modules and wires them together (see [Top-Level Folder Reference](#top-level-folder-reference)) |
| `systm--` | Cross-cutting system defaults (e.g. per-service port defaults) |

```
# nix flake show (abbreviated)
├───nixosConfigurations
│   ├───nixace, nixnas1, nixnas2, nixsun, nixtop, nixvat, nixzen
├───nixosModules
│   ├───hardw--zb17g4-p5, hardw--profl--workstation-nvidia, hosts--nixace, servc--glance-nixlab, stack--monitoring, ...
├───homeModules
│   ├───home--profl--base, home--profl--desktop, home--core--config-git, home--apps--browsers, ...
```

</details>

- ### <ins>Three-Axis Metadata: Hardware, Hosts & Users</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Physical hardware, host identity, and user identity are three deliberately independent axes — none is hardcoded into another. This is what lets any number of users mix and match across any number of hosts (e.g. `temhr` on `nixace`; `temhr` and `guest` on `nixvat`; `guest` and `rhmet` on `nixsun`), and lets the same hardware profile (e.g. `workstation-nvidia`) back multiple distinct machines, without per-combo boilerplate.

**Axis 0 — `hardwareMeta` (physical machine facts, independent of hostname):**
```nix
# flake/data/hardware-meta.nix — mkMachineMeta itself lives in flake/schema/hardware.nix
flake.lib.hardwareMeta = {
  zb17g1-k3 = mkMachineMeta {
    cpuVendor = "intel";
    initrdAvailableKernelModules = ["xhci_pci" "ehci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"];
    kernelModules = ["kvm-intel"];
  };
  # ...one entry per physical machine, in nixlab's own schema —
  # never a raw nixos-generate-config dump.
};
```
`self.lib.mkHardwareProfile "<machine>"` (in `flake/builders/hardware.nix`) reads this metadata directly, keyed by the **machine name passed in explicitly** — never by `config.networking.hostName`, since the machine nickname and the eventual hostname are different identifier spaces (see [Module Namespace & Naming](#module-namespace--naming)):
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

**Axis 1 — `usersMeta` (who, independent of where):**
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

**Axis 2 — `hostsMeta` (where, independent of who):**
```nix
# flake/data/hosts-meta.nix — mkHostMeta itself lives in flake/schema/hosts.nix
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

**Real per-combo files are an escape hatch, not the default.** `home/users/<username>-<hostname>.nix` (referenced via `hostOverrides.<host>.extraModules`) is created only when a specific user@host combination has genuinely unique content (e.g. GPU tooling only relevant to `temhr` on `nixace`) — mirroring exactly how sparse `hosts/nixzen.nix` and substantial `hosts/nixace.nix` coexist: file richness tracks real uniqueness, not a uniform template. `hardwareMeta` has the identical escape hatch via each entry's `extraConfig` field, for the rare machine with a genuinely exotic one-off boot requirement.

</details>

- ### <ins>Profile Composition</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Every `nixosConfiguration` and every generated home-manager user composes from the same three-tier shape:

**Hardware side** (`hardware/common/profile-*.nix`):
- `mkHardwareProfile "<machine>"` (a function, not a self-registered module — called by each machine file, not imported) — universal filesystem layout, per-machine boot/initrd/kernel-module facts sourced from `hardwareMeta`, CPU microcode
- `hardw--profl--workstation-nvidia` — nvidia driver + local `/data` mount + mirror-peer NFS mounts; imported by the 5 nvidia-equipped workstation/laptop machines

**NixOS side** (`hosts/common/profile-*.nix`):
- `hosts--profl--base` — boot loader, networking, nix settings, ssh, sops, `stack--monitoring`, home-manager wiring, automation timers; imported by every host
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
├── flake/                             # Orchestration-level flake-parts configurations
│   ├── data/                          # pure attrsets only — no functions
│   ├── schema/                        # smart constructors (mk<axis>Meta, ...), validates attrsets
│   ├── builders/                      # generates configs (nixosConfigurations, ...) from metadata
│   ├── ci/                            # dev-facing tooling
│   ├── nixos-lib.nix                  # service module helper functions
│   └── pkgs.nix                       # where overlays / .nixpkgsConfig are defined for pkgs
│
├── hardware/                          # Machine-level hardware configurations
│   ├── common/
│   |   ├── drivers/                   # driver-branch enum
│   |   ├── mounts/                    # local-data, mirror-peer, zfs-raidz1-pool, ...
│   |   └── profile-*.nix, ...
│   └── <model>.nix                    # Per-device hardware configuration + module registration
│
├── hosts/                             # System-level NixOS configurations
│   ├── common/
│   |   ├── apps/                      # Toggleable software modules
│   |   ├── automation/                # Scheduled tasks
│   |   ├── core/                      # Universal modules
│   |   │   └── users.nix              # users-main, users-hm, users-sys
│   |   ├── debug/                     # diagnose.nix — opt-in only
│   |   ├── desktop/                   # Desktop-only modules
│   |   ├── hardware/                  # Physical hardware modules
│   |   ├── _host-template.nix
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
│   |   ├── comfyui/
│   |   ├── glance/
│   |   ├── homepage-dashboard/
│   |   ├── monitoring/                # alertmanager/, grafana/, loki/, ntfy/, prometheus/
│   |   └── <service>.nix
│   └── ports.nix                      # systm--ports-* per-service defaults (mkDefault)
│
├── stacks/                            # stack--* — multi-service integration bundles
│   └── monitoring.nix
│
├── sops/                              # Centralized secrets management
│   ├── <service>.nix                  # Secret module declarations (nsops--*)
│   └── <service>.yaml                 # Encrypted secrets per module
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

</details>

---

## Top-Level Folder Reference

Every top-level folder answers one question: *what kind of thing does a file in here become?* Before creating a new file anywhere in this repo, find its folder below and check its file requirements — this is what keeps the self-registering, no-central-import architecture from turning into "put it wherever seems fine."

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

### `flake/` — orchestration: metadata, constructors, generators, dev tooling

**Why it exists:** every other folder in this repo depends on `flake/` (metadata to describe a host/user/machine, generator functions to build real config from that metadata) but `flake/` depends on nothing else — it's the foundation, so it's the one folder organized by *kind of thing* rather than *feature*.

| Subfolder | Contains | File must... |
|---|---|---|
| `data/` | Pure attrsets. No functions, no `mkOption`, no logic. | Contain only calls to a `schema/` constructor (`mkHostMeta {...}`, `mkMachineMeta {...}`) or plain literal values. Never reference `config`, never define a NixOS/home-manager module. Safe to read without evaluating anything beyond basic Nix. |
| `schema/` | Option declarations and smart constructors (`mk<Axis>Meta`) that validate/default-fill `data/`'s attrsets. | Export exactly one constructor function (or a small option-declaration file like `options.nix`) per axis. A typo'd field name here must produce a real error, not a silent `null`. |
| `builders/` | One file per independent axis (hardware, hosts, users) — turns validated metadata into real `nixosConfigurations`/`home-manager.users`. | Consume `self.lib.<axis>Meta`, never import another `flake/` file by relative path. Export via `flake.lib.<name>`, never inline logic that belongs in `schema/`. |
| `ci/` | `checks.nix`, `apps.nix`, `packages.nix` — dev-facing tooling. | Never referenced by any host/user/machine config. This is plumbing for working on the repo, not part of what the repo *means*. |
| `nixos-lib.nix` (bare file, not a subfolder) | Shared NixOS helper functions (`mkNginxVirtualHost`, `mkServiceHardening`, ...) used across many service modules. | Stay cross-cutting — if a function only makes sense for one service, it belongs in that service's own module, not here. |
| `pkgs.nix` (bare file) | Single source of truth for overlays + `nixpkgsConfig`, consumed by both `perSystem` and every per-host `pkgs` set. | Never be duplicated — this file exists specifically to close the "hand-copied overlay list" gap. |

### `hardware/` — physical machine facts

**Why it exists:** boot/initrd/kernel-module facts and filesystem layout are properties of a physical box, entirely independent of what hostname or users that box ends up running.

- **One file per machine** (`hardware/<machine>.nix`) — must call `(self.lib.mkHardwareProfile "<machine>")` with the machine's own filename as the string, plus whichever `hardw--profl--*`/`hardw--mounts--*` modules it needs. Must never look up its identity via `config.networking.hostName`.
- **`common/drivers/`, `common/mounts/`** — atomic, single-purpose, reusable across any machine. A mount module must be parameterized (pool name, peer list, device paths as options) — never hardcode one machine's nickname into a supposedly-generic module's option namespace.
- **`common/profile-*.nix`** — composes drivers/mounts into a named hardware role (e.g. `workstation-nvidia`), imported by multiple machine files.

### `hosts/` — NixOS system identity & composition

**Why it exists:** this is where a physical/logical machine becomes a bootable `nixosConfiguration` — host identity, profile selection, and genuinely unique per-host feature config.

- **`hosts/<hostname>.nix`** — must call `self.lib.mkHost { name; modules; }`. The `hosts--<hostname>` module inside it should contain only feature toggles (`steam.enable = true;`) and config that's *genuinely unique to this host* — never `nixlab.mainUser`, never home-manager user lists (both are derived from `hostsMeta`).
- **`common/core/`** — universal, non-toggleable modules imported by every host via `hosts--profl--base`. A file belongs here only if *every* host needs it unconditionally — if it's optional, it belongs in `apps/` with a real `enable` option instead.
- **`common/apps/`, `common/desktop/`, `common/automation/`, `common/hardware/`** — toggleable or role-scoped modules, each with `lib.mkEnableOption`-style options, composed into profiles rather than imported directly by host files.
- **`common/debug/`** — opt-in diagnostics only. Must never appear in any `profile-*.nix` — a debug module that's silently always-on defeats its own purpose.
- **`common/_host-template.nix`** — reference only, never imported by the flake (prefixed `_` and excluded from real registration for exactly this reason).

### `home/` — home-manager user identity & composition

**Why it exists:** mirrors `hosts/` exactly, one layer down — per-user, session-scoped config instead of per-host, system-scoped config. See [System Space vs. User Space](#three-axis-metadata-hardware-hosts--users) for the deciding rule on whether something belongs here or in `hosts/`.

- **`common/core/`** — universal home-manager modules, imported by every user via `home--profl--base`. Same "unconditional or it doesn't belong here" rule as `hosts/common/core/`.
- **`common/apps/`** — toggleable, per-user preference modules (browsers, terminal emulators). If a feature needs a system daemon (e.g. `virtualisation.libvirtd`), that daemon belongs in `hosts/`, not here — only the per-user preference layer on top does.
- **`common/shell/`** — dotfile/shell-integration modules. Should read directory contents (`builtins.readDir`) rather than hand-listing every file, wherever the underlying file set can grow over time (see `bash.nix`'s alias-loading pattern).
- **`users/`** — an escape hatch, not a default. A file belongs here only for a specific user@host combination with genuinely unique content, wired in via `usersMeta.<user>.hostOverrides.<host>.extraModules` — never a uniform per-user template.

### `modules/` — atomic service modules

**Why it exists:** the "one service, one file (or one directory), zero knowledge of any other service" tier. This is intentionally the *most* restrictive folder in the repo.

**A file belongs in `modules/nixos/<service>/` only if all of the following hold:**
1. It declares `options.services.<service>-nixlab.*` and nothing outside that namespace (beyond the user/group/systemd unit it owns).
2. Its `config` block never sets an option under a *different* service's namespace (e.g. `servc--grafana-nixlab` must never set `services.prometheus-nixlab.*`). If it needs to, that's the signal it should move to `stacks/`.
3. Its `serviceConfig` is built from `nixlabLib.mkServiceHardening`, with any deviation using a named flag (`allowJIT`, `allowDevices`) rather than a hand-rolled override — see [Coupling Principles](#coupling-principles).
4. It provides its own escape-hatch options (e.g. `extraScrapeConfigs`, `provisioning.datasources`) for anything a `stacks/` file might need to inject, rather than a stack reaching into `systemd.services.*` directly.

`ports.nix` is the one exception living at this folder's root rather than nested — it's genuinely cross-cutting (default ports for every service) rather than belonging to any single service.

### `stacks/` — multi-service integration bundles

**Why it exists:** some services must communicate to actually function well together (Grafana needs Prometheus/Loki as datasources; Prometheus needs to know Alertmanager's address; Alertmanager needs a notification channel). That wiring has to live *somewhere* — putting it inside any one service module would give that module illegitimate knowledge of its siblings, which is exactly the kind of coupling this repo's conventions exist to avoid. `stacks/` is that "somewhere."

**A file belongs in `stacks/` — and should be named `stack--<name>` — only if:**
1. It imports **two or more** `servc--`/`nsops--` modules.
2. It sets at least one option belonging to a service *other than* the one whose module it happens to be adjacent to in the import list — i.e., it does real cross-wiring, not just co-importing. (Two services imported together with no cross-reference between them don't need a stack file; plain composition in a host file is enough.)
3. It implements **no service logic of its own** — no `systemd.services.*`, no `users.users.*`. Everything it does is set options that the underlying `servc--`/`nsops--` modules already declared (including any `extraScrapeConfigs`/`provisioning.*`-style escape hatches added specifically for this purpose).
4. It exposes its own aggregator option (e.g. `services.nixlab-monitoring.*`) so a host consumes one coherent interface rather than five separate `enable`s plus manual wiring repeated per host.

If a candidate file would satisfy #1 but not #2 — e.g. ComfyUI's three cooperating modules (`comfyui-p5000`, `comfyui-extensions`, `comfyui-models`), which all target the *same* service's option namespace rather than wiring peer services together — it stays in `modules/`, not `stacks/`. The test is "do two *different* services' option surfaces get touched," not "do multiple files work together."

### `sops/` — secrets

**Why it exists:** secret material must never enter the Nix store; sops-nix decrypts at activation time, and the wiring from encrypted file to service option needs its own home separate from both the service module and the secret content itself.

- **One `.nix` + one `.yaml` pair per service**, named identically to the service. The `.nix` file: `imports = [ self.nixosModules.servc--<service>-nixlab ];` (a structural dependency, not a runtime assertion), declares `sops.secrets.*`, and wires exactly one decrypted path into exactly one option the service module already declared. Never sets any option outside that one field — see [Secrets Management](#secrets-management) for the `checkConfig` cautionary example.
- Global, host-independent settings (`sops.age.keyFile`) belong in `hosts/common/core/`, never in an optional `sops/*.nix` module, since every secret on every host depends on it regardless of which optional services are enabled.

### `overlays/`, `shells/`, `cachix/`, `pkgs/`, `bin/`

**Why they exist:** self-contained, single-purpose flake outputs with no cross-folder dependencies, no shared naming convention because nothing else in the repo needs to reference them by a stable name the way `nixosModules`/`homeModules` do.

- **`overlays/`** — one file per overlay, each a `final: prev: {...}` function, registered in `flake.overlays.*` via `default.nix`.
- **`shells/`** — one file per `devShell`, registered in `perSystem.devShells.*`.
- **`cachix/`** — one file per binary cache substituter.
- **`pkgs/`** — custom package derivations, registered in `perSystem.packages` via `default.nix`.
- **`bin/`** — standalone scripts meant to be run directly by a human, never referenced by any Nix module. If a script needs to be *part of* system/user config (e.g. installed as a package, run by a systemd unit), it belongs inside the relevant service module instead, not here.

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

A "host" (network identity, users, services — `hostsMeta`) and a "machine" (physical hardware — `hardwareMeta`) are independent concerns here; a new physical box needs both, and an existing machine can in principle be reinstalled under a new hostname without redoing its hardware facts.

#### 1. Capture the machine's hardware facts once, add to `flake/data/hardware-meta.nix`

Boot the installer on the physical machine and run (non-destructive, doesn't touch anything):
```bash
nixos-generate-config --show-hardware-config
```
Transcribe only the genuinely machine-specific facts — everything else in nixlab's own schema is either a fleet-wide default or already standardized by consistent partition labels:
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

No raw `hardware-configuration.nix` file is created or pasted anywhere — `mkHardwareProfile` reads the metadata above directly, keyed by the explicit string passed in:
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
  wifiIface = "wlp3s0";              # Find with: ip link (omit if no wifi)
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

Home-manager users are **generated**, not hand-written per host. Adding a new user, or adding an existing user to a new host, is a metadata change only.

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

`mkHomeUsersForHost` and `mkSystemUsersForHost` will generate both the home-manager profile and the NixOS account automatically on the next rebuild.

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

Service modules live in `modules/nixos/<service>/`. Secrets are managed separately in `sops/`.

> Shared helpers (`mkNginxVirtualHost`, `mkFirewallPorts`, `mkServiceHardening`, `mkSslAssertion`) are available in any module via `{ nixlabLib, ... }:` — see `flake/nixos-lib.nix` for usage examples, and [Coupling Principles](#coupling-principles) for `mkServiceHardening`'s `allowNetwork`/`allowDevices`/`allowJIT` flags.

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
