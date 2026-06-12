# nixlab

Modular NixOS configuration for Linux laptops, desktops, and homelab servers. Built on the **Dendritic Pattern** using **flake-parts** for composable, self-registering modules where every file declares its own outputs.

Adapted from [Misterio77's nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) with inspiration from [EmergentMind](https://www.youtube.com/watch?v=YHm7e3f87iY&list=PLAWyx2BxU4OyERRTbzNAaRHK08DQ0DD_l&index=1), [Vimjoyer](https://www.youtube.com/@vimjoyer), and the broader NixOS community. Written almost entirely by Claude.

---

**Table of Contents**
- [Nix Ecosystem Terminology](#nix-ecosystem-terminology)
- [Architecture](#architecture)
  - [flake-parts Orchestration](#flake-parts-orchestration)
  - [The Dendritic Pattern](#the-dendritic-pattern)
  - [Self-Exporting Module Schema](#self-exporting-module-schema)
  - [nixosModules Namespace](#nixosmodules-namespace)
  - [Central Orchestration Files](#central-orchestration-files)
  - [Secrets Management](#secrets-management)
- [Dependency & Import Flow](#dependency--import-flow)
  - [Top-Level Entry Point](#top-level-entry-point)
  - [Host Build Flow](#host-build-flow)
  - [Profile Composition](#profile-composition)
  - [Module Naming & Resolution](#module-naming--resolution)
- [Repository Layout](#repository-layout)
- [Usage](#usage)
  - [First Install](#first-install-on-a-new-machine)
  - [Daily Commands](#daily-commands)
  - [Adding a New Host](#adding-a-new-host)
  - [Adding a New Service Module](#adding-a-new-service-module)

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
- **Modules**: Self-contained Nix files that declare options and implement configuration. The NixOS module system merges modules together, resolving option definitions across all imported files into a final coherent system configuration
- **Overlays**: Functions of the form `final: prev: { ... }` that extend or modify a nixpkgs instance. Overlays can add new packages, override existing ones, or expose pinned package sets alongside the default channel

</details>

---

## Architecture

nixlab uses **flake-parts** as its orchestration layer, structured around the **Dendritic Pattern** and a **self-exporting module schema** where every file registers its own outputs directly into the flake — no central registry required.

- ### <ins>flake-parts Orchestration</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

[flake-parts](https://github.com/hercules-ci/flake-parts) is a NixOS community library that structures flake outputs as composable modules called **parts**. Instead of one monolithic `outputs = { ... }` function, each concern lives in its own file and declares exactly what it contributes.

The `flake.nix` root is a thin entry point that uses [import-tree](https://github.com/vic/import-tree) to auto-discover all part files across multiple directories:

```nix
outputs = inputs @ { flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    imports = [
      (inputs.import-tree ./flake)
      (inputs.import-tree ./hardware)
      (inputs.import-tree ./home)
      (inputs.import-tree ./hosts)
      (inputs.import-tree ./modules)
      (inputs.import-tree ./overlays)
      (inputs.import-tree ./shells)
      (inputs.import-tree ./sops)
    ];
  };
```

**Key benefits:**
- Adding a new self-exporting file to any discovered directory requires no changes to `flake.nix`
- `perSystem` is called automatically for each supported system
- Architecture-independent outputs use the `flake.` namespace
- Files prefixed with `_` are leaf files excluded from import-tree discovery

</details>

- ### <ins>The Dendritic Pattern</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

The Dendritic Pattern organizes NixOS configuration around **features rather than hostnames**. The name comes from the branching, self-similar structure where each part of the config is independent and composable.

**The key shift** is in the axis of composition: instead of asking _"what does this machine need?"_ and building outward from a hostname, you ask _"which features does this machine require?"_ and assemble inward from capabilities.

In practice:
- **Shared behaviour** lives in domain-grouped modules under `hosts/common/` — `core/` for universals, `desktop/` for display-specific concerns, `apps/` for toggleable software, `automation/` for scheduled tasks, `hardware/` for physical concerns
- **Profiles** (`profile-base`, `profile-desktop`, `profile-nas`) compose those modules into role-appropriate bundles
- **Host files** become pure feature manifests — short declarations selecting a profile and enabling specific apps or services
- **Adding a new host** means writing three small files (host, home, hardware) plus a metadata entry — no deep knowledge of filesystem layout required
- **Changing a feature** happens in one place and propagates to every host that selects it

</details>

- ### <ins>Self-Exporting Module Schema</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Almost every file in this flake is a **flake-parts module**. A **flake-parts module** is a function that takes `{ self, inputs, ... }` and registers its own outputs directly into the flake. There is no central registry. Each file is fully self-sufficient:

```nix
# modules/nixos/glance/default.nix
{ ... }: {
  flake.nixosModules.servc--glance-nixlab = { config, lib, pkgs, ... }: {
    options.services.glance = { ... };
    config = lib.mkIf config.services.glance.enable { ... };
  };
}
```

```nix
# hosts/nixace.nix
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
      # ...
    ];
  };

  flake.nixosModules.hosts--nixace = { ... }: {
    nixlab.mainUser = "temhr";
    gShells.DE = "plasma6";
    blender.enable = true;
    steam.enable = true;
    # feature selections only — no imports, no inline configs
  };
}
```

**Key principles:**
- Files reference each other exclusively by **output name** (`self.nixosModules.*`) — never by filesystem path
- Files can be freely moved or renamed without breaking consumers
- A single file can emit multiple related outputs (e.g., a service module alongside its host config)
- The name is the contract, not the path

</details>

- ### <ins>nixosModules Namespace</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

All NixOS modules are registered under `flake.nixosModules` using a nested namespace that groups them by concern. Module names use a double-dash separator to create a readable hierarchy:

**Naming convention:**
- `hardw--<identifier>`: Hardware configurations
- `hosts--<identifier>`: Host configurations, profiles, and feature selections
- `hosts--profl--<identifier>`: Profile compositions (base, desktop, nas)
- `hosts--core--<identifier>`: Universal core modules
- `hosts--deskt--<identifier>`: Desktop-specific modules
- `hosts--apps--<identifier>`: Toggleable application modules
- `hosts--autom--<identifier>`: Automation and scheduled task modules
- `hosts--hardw--<identifier>`: Shared hardware concern modules
- `hosts--debug--<identifier>`: Opt-in debug/diagnostic modules
- `servc--<identifier>`: Self-hosted service modules
- `nsops--<identifier>`: sops-nix secret modules (auto-discovered from `sops/`)

**Example output tree:**
```
├───nixosConfigurations
│   ├───nixace: NixOS configuration
│   ├───nixnas1: NixOS configuration
│   ├───nixnas2: NixOS configuration
│   ├───nixsun: NixOS configuration
│   ├───nixtop: NixOS configuration
│   ├───nixvat: NixOS configuration
│   └───nixzen: NixOS configuration
├───nixosModules
│   ├───hardw--zb17g4-p5: NixOS module
│   ├───hosts--profl--base: NixOS module
│   ├───hosts--profl--desktop: NixOS module
│   ├───hosts--profl--nas: NixOS module
│   ├───hosts--core--nix: NixOS module
│   ├───hosts--core--networking: NixOS module
│   ├───hosts--core--monitoring: NixOS module
│   ├───hosts--deskt--gui-shells: NixOS module
│   ├───hosts--deskt--firefox: NixOS module
│   ├───hosts--apps--development: NixOS module
│   ├───hosts--apps--games: NixOS module
│   ├───hosts--autom--backup-home: NixOS module
│   ├───hosts--autom--ping-watchdog: NixOS module
│   ├───hosts--debug--diagnose: NixOS module
│   ├───servc--glance-nixlab: NixOS module
│   ├───servc--grafana-nixlab: NixOS module
│   ├───nsops--glance: NixOS module
│   ├───nsops--ssh-keys: NixOS module
│   └───...
```

Run `nix flake show` to see the complete module tree.

</details>

- ### <ins>Central Orchestration Files</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

A small number of concerns remain in `flake/parts/` as conventional flake-parts files rather than self-registering modules.

| File | Responsibility | Output namespace |
|------|---------------|------------------|
| `lib.nix` | Defines `mkHost` helper; reads `_hosts-meta.nix`; wires common modules (sops-nix, home-manager, overlays) | `flake.lib` |
| `_hosts-meta.nix` | Static `hostsMeta` attrset containing per-host metadata: IP addresses, network interfaces, system architecture, nixpkgs input selection | *(imported by `lib.nix`)* |
| `options-home.nix` | Declares `flake.homeModules` as a mergeable `lazyAttrsOf` option for collision-free contributions | `flake.homeModules` |
| `nixpkgs.nix` | Configures the default `pkgs` instance for all `perSystem` blocks with `allowUnfree = true` and applies all overlays | `perSystem._module.args.pkgs` |
| `packages.nix` | Imports custom packages from `pkgs/` directory | `perSystem.packages` |
| `checks.nix` | Pre-commit hooks (alejandra, deadnix, merge-conflict guards) and formatter configuration | `perSystem.checks`, `perSystem.formatter` |
| `apps.nix` | Defines the `build-all` app that validates all `nixosConfiguration` outputs | `perSystem.apps.build-all` |

**Key orchestration features:**
- **Per-host nixpkgs selection**: `_hosts-meta.nix` allows different hosts to use different nixpkgs inputs (stable, unstable, or pinned versions)
- **Centralized overlays**: All overlays are applied uniformly across all configurations
- **Metadata-driven networking**: IP addresses and interface names are centralized in `_hosts-meta.nix` for easier network management

</details>

- ### <ins>Secrets Management</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Secrets are managed with sops-nix using age encryption. All [sops-nix](https://github.com/Mic92/sops-nix) secrets-related files are centralized in the `sops/` directory:

- **Encrypted secrets**: Each service has a dedicated `.yaml` file (e.g., `sops/glance.yaml`, `sops/grafana.yaml`, `sops/ssh-keys.yaml`)
- **Secret modules**: Corresponding `sops/<service>.nix` files declare which keys to decrypt and wire them to services
- **Self-registering**: Secret modules follow the flake-parts pattern, registering as `flake.nixosModules.nsops--<service>`
- **File-based options**: Service modules accept `*File` path options (not plaintext strings)
- **Runtime decryption**: Decrypted paths are passed via `config.sops.secrets.<KEY>.path`

**Key design patterns:**

1. **Centralized location**: All secrets live in `sops/` for easier auditing and rotation
2. **Configurable paths**: Secret modules expose a `secretsFile` option (defaults to co-located `.yaml`) for per-host overrides
3. **Automatic wiring**: Secret modules are conditionally enabled based on service enablement
4. **Service coupling**: Secrets modules are imported separately in host configurations alongside their service modules

**Example structure:**
```
sops/
├── glance.nix               # Declares nsops--glance module
├── glance.yaml              # Encrypted secrets for glance
├── ssh-keys.nix             # Declares nsops--ssh-keys module
├── ssh-keys.yaml            # Encrypted SSH private keys
├── networking.nix           # Declares nsops--networking module
└── networking.yaml          # Shared networking secrets (wifi credentials)
```

**SSH Key Management:**

SSH private keys (like the GitHub nixlab repository key) are managed declaratively through sops-nix:

- **Encrypted storage**: Private keys stored in `sops/ssh-keys.yaml` (safe to commit)
- **Runtime decryption**: Keys decrypted to `/run/secrets/ssh_key_*` at boot with proper permissions (0400, user ownership)
- **Interactive use**: Symlinks created at `~/.ssh/id_*` pointing to decrypted secrets for command-line operations
- **Service use**: Systemd services reference `/run/secrets/ssh_key_*` directly via `GIT_SSH_COMMAND`

**Common secret management patterns:**

1. **Simple environment file** (`glance`, `homepage`): Single `SERVICENAME_ENV` secret containing KEY=value lines, loaded via `EnvironmentFile`
2. **Multiple discrete secrets** (`grafana`, `bookstack`): Individual secrets declared with `lib.genAttrs`, each accessible separately in the service config
3. **Dedicated oneshot service** (`node-red`): A systemd oneshot service builds the environment file from multiple secrets at runtime
4. **YAML file passthrough** (`home-assistant`): The entire decrypted secret is installed as `secrets.yaml` in the service's data directory
5. **Shared secrets** (`networking`): Common credentials (WiFi SSID/password) used across multiple hosts
6. **SSH private keys** (`ssh-keys`): Encrypted private keys with dual access via `/run/secrets/` (services) and `~/.ssh/` symlinks (interactive)

**Encrypting and managing secrets:**

```bash
# Encrypt a new or existing secrets file
sops sops/<service>.yaml

# Edit encrypted secrets
sops sops/<service>.yaml

# Update all secrets after modifying .sops.yaml
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
  nix-shell -p sops --run "sops updatekeys sops/*.yaml"

# View decrypted content (does not modify)
sops -d sops/<service>.yaml
```

| Secret Type | Encrypted Location | Decrypted Location | Interactive Access |
|-------------|-------------------|-------------------|-------------------|
| Service secrets | `sops/service.yaml` | `/run/secrets/SERVICE_*` | N/A |
| SSH keys | `sops/ssh-keys.yaml` | `/run/secrets/ssh_key_*` | `~/.ssh/id_*` (symlink) |

</details>

---

## Dependency & Import Flow

This section maps how configuration flows from the `flake.nix` entry point through every layer of the repository down to a final built NixOS system.

- ### <ins>Top-Level Entry Point</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

`flake.nix` is a pure delegation layer. It has no logic of its own — it hands control to `flake-parts` and uses `import-tree` to recursively discover every `.nix` file in each top-level directory. Each discovered file is a self-registering flake-parts module that contributes to the shared `flake.*` and `perSystem.*` output namespaces.

```
flake.nix
└── flake-parts.lib.mkFlake
    └── import-tree (auto-discovers all .nix files in:)
        ├── flake/          → orchestration (lib, nixpkgs, checks, apps, options)
        ├── hardware/       → registers hardw--* nixosModules
        ├── home/           → registers homeModules.*
        ├── hosts/          → registers hosts--* nixosModules + nixosConfigurations
        ├── modules/        → registers servc--* nixosModules
        ├── overlays/       → registers flake.overlays.*
        ├── shells/         → registers perSystem.devShells.*
        └── sops/           → registers nsops--* nixosModules
```

All outputs from every discovered file are merged together by flake-parts into a single coherent flake output. Files prefixed with `_` are leaf imports consumed by their parent and are excluded from auto-discovery.

</details>

- ### <ins>Host Build Flow</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

When `nixos-rebuild` builds a host, it evaluates `flake.nixosConfigurations.<hostname>`. Each configuration is constructed by `self.lib.mkHost`, which is defined in `flake/parts/lib.nix` and wires together all module layers:

```
nixosConfigurations.nixace
└── self.lib.mkHost { name = "nixace"; modules = [...]; }
    │
    │  (lib.nix injects these automatically for every host)
    ├── nixpkgs instance  ← selected per-host from _hosts-meta.nix
    ├── sops-nix module   ← inputs.sops-nix.nixosModules.sops-nix
    ├── overlays          ← all four overlays applied to pkgs
    ├── hostMeta          ← per-host attrset (IP, interfaces, etc.)
    │
    │  (declared explicitly in the host's modules = [...] list)
    ├── hardw--zb17g4-p5          # physical hardware (filesystems, kernel modules)
    ├── hosts--nixace             # host identity + app/service feature selections
    ├── hosts--profl--base        # universal profile (see Profile Composition below)
    ├── hosts--profl--desktop     # desktop profile (see Profile Composition below)
    ├── servc--bookstack-nixlab   # BookStack service module
    ├── nsops--bookstack          # BookStack secrets wiring
    ├── servc--comfyui-p5000      # ComfyUI service module
    ├── servc--ollama             # Ollama service module
    └── nsops--ollama             # Ollama secrets wiring
```

The NixOS module system then merges all of these modules together — resolving options, applying `lib.mkIf` guards, and producing a single evaluated system configuration that is passed to `nixpkgs.lib.nixosSystem`.

</details>

- ### <ins>Profile Composition</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Profiles are pure import lists — they contain no new configuration of their own, only `imports = [...]`. They define what a role-type machine receives without any host needing to enumerate it manually.

```
hosts--profl--base
├── hosts--core--boot-loader        # systemd-boot, generation limit
├── hosts--core--display-manager    # autoLogin default
├── hosts--core--home-manager-config
├── hosts--core--journald           # log size limits, retention
├── hosts--core--locale             # en_CA, America/Toronto
├── hosts--core--monitoring         # Prometheus + Loki + Grafana (mandatory)
├── hosts--core--networking         # NetworkManager, firewall, wifi via sops templates
├── hosts--core--nginx              # recommended settings (active only if nginx enabled)
├── hosts--core--nix                # flakes, registry, store optimisation
├── hosts--core--open-ssh           # sshd, key-only auth, no root login
├── hosts--core--sops               # age key path, default format
├── hosts--core--system             # XDG_RUNTIME_DIR, CUPS
├── hosts--core--users              # nixlab.mainUser option, user accounts, HM dispatch
├── hosts--core--utilities          # system-wide CLI tools
├── hosts--autom--nix-gc            # daily garbage collection
├── hosts--autom--nixos-upgrade     # automated flake-based system upgrades
├── hosts--autom--nixlab-gpull      # hourly git pull of nixlab repo
├── servc--homepage-nixlab          # Homepage dashboard (mandatory)
└── nsops--ssh-keys                 # GitHub SSH key decryption


hosts--profl--desktop
├── hosts--apps--development        # blender, godot, vscodium toggles
├── hosts--apps--education          # anki toggle
├── hosts--apps--games              # steam toggle
├── hosts--apps--media              # obs, spotify, vlc toggles
├── hosts--apps--productivity       # calibre, libreoffice, logseq toggles
├── hosts--apps--virtualizations    # incus, quickemu, wine, etc. toggles
├── hosts--deskt--firefox           # system-wide Firefox with policies + extensions
├── hosts--deskt--flatpak           # Flatpak + Flathub + auto-update
├── hosts--deskt--gui-shells        # GNOME / Plasma6 selector
├── hosts--deskt--ignore-lid        # lid-close behaviour + sleep inhibit
├── hosts--hardw--audio             # PipeWire + ALSA + PulseAudio compat
├── hosts--hardw--bluetooth         # hardware.bluetooth enable
├── hosts--hardw--power-management  # HDD APM, AHCI LPM, sysctl I/O tuning
├── hosts--autom--backup-home       # nightly rsync home backup
├── hosts--autom--flake-update      # nightly flake.lock update + git push
└── hosts--autom--ping-watchdog     # internet watchdog with exponential backoff reboot


hosts--profl--nas
└── hosts--autom--backup-phone-media  # nightly move of phone photos from Syncthing share
```

A desktop host (`nixace`, `nixtop`, `nixsun`, `nixvat`, `nixzen`) imports both `base` and `desktop`. A NAS host (`nixnas1`, `nixnas2`) imports `base` and `nas`. The difference in what each machine type receives is entirely determined by which profiles are in its `modules = [...]` list.

</details>

- ### <ins>Module Naming & Resolution</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

No file in this repo imports another by filesystem path (with the exception of `_` prefixed leaf files consumed by their direct parent). All cross-file references use the `self.nixosModules.*` or `self.homeModules.*` output namespaces. This means:

- A module can be moved to any directory without breaking any consumer
- The name in the namespace is the only stable contract
- `nix flake show` always reflects the true current state

The double-dash naming scheme encodes a two-level hierarchy in a flat namespace:

```
hosts--profl--base        →  hosts / profile / base
hosts--core--networking   →  hosts / core concern / networking
hosts--apps--games        →  hosts / apps layer / games
hosts--deskt--firefox     →  hosts / desktop layer / firefox
hosts--autom--backup-home →  hosts / automation / backup-home
hosts--hardw--audio       →  hosts / hardware concern / audio
hosts--debug--diagnose    →  hosts / debug (opt-in only) / diagnose
servc--bookstack-nixlab   →  service / bookstack
nsops--bookstack          →  sops secrets / bookstack
hardw--zb17g4-p5          →  hardware / specific machine model
```

The `debug/` layer (`hosts--debug--diagnose`) is intentionally isolated and never included in any profile. It must be explicitly added to a host's module list, making it impossible to accidentally ship crash-dump kernel settings to a production machine.

</details>

---

## Repository Layout

```
nixlab/
├── flake.nix                        # Thin root — delegates to directories via import-tree
├── flake.lock                       # Version-pinned input revisions
│
├── flake/                           # Orchestration-level flake-parts configs
│   └── parts/
│       ├── _hosts-meta.nix          # Static per-host metadata: IPs, interfaces, nixpkgs
│       ├── apps.nix                 # build-all app: validates every nixosConfiguration
│       ├── checks.nix               # Pre-commit hooks (alejandra, deadnix, guards) + formatter
│       ├── lib.nix                  # mkHost constructor; reads hostsMeta; wires modules + overlays
│       ├── nixpkgs.nix              # Configs pkgs instance (allowUnfree + overlays) for perSystem
│       ├── options-home.nix         # Declares flake.homeModules as mergeable lazyAttrsOf option
│       └── packages.nix             # Imports pkgs/ into perSystem.packages
│
├── hardware/                        # Machine-level hardware configs (self-registering)
│   └── <model>.nix                  # Per-device hardware: filesystems, kernel modules, platform
│
├── hosts/                           # System-level NixOS configurations (self-registering)
│   ├── <hostname>.nix               # nixosConfiguration + hosts--<hostname> module declaration
│   └── common/
│       ├── profile-base.nix         # hosts--profl--base: universal module composition
│       ├── profile-desktop.nix      # hosts--profl--desktop: desktop module composition
│       ├── profile-nas.nix          # hosts--profl--nas: NAS module composition
│       ├── core/                    # Universal modules (imported by profile-base)
│       │   └── _users/              # nixlab.mainUser option + user account definitions
│       ├── desktop/                 # Desktop-only modules (imported by profile-desktop)
│       ├── hardware/                # Physical hardware modules (imported by profile-desktop)
│       ├── apps/                    # Toggleable software modules (imported by profile-desktop)
│       ├── automation/              # Scheduled tasks (split between base and desktop profiles)
│       └── debug/                   # Opt-in only — never included in any profile
│
├── home/                            # User-level Home Manager configurations
│   ├── common/
│   │   ├── files/                   # Managed dotfiles and scripts
│   │   ├── global/                  # Applied to all users unconditionally
│   │   └── optional/                # Selectable user-package modules
│   └── <username>/
│       └── <hostname>.nix           # User environment for specific host
│
├── modules/                         # Reusable self-exporting service modules
│   ├── nixos/                       # System-level service modules (servc--*)
│   │   └── <service>/
│   │       └── default.nix
│   └── home-manager/                # User-level service modules
│
├── sops/                            # Centralized secrets management
│   ├── <service>.nix                # Secret module declarations (nsops--*)
│   ├── <service>.yaml               # Encrypted secrets per service
│   ├── ssh-keys.nix
│   ├── ssh-keys.yaml
│   ├── networking.nix
│   └── networking.yaml
│
├── overlays/                        # nixpkgs modifications and channel pinning
│   ├── default.nix                  # Self-registers all overlays into flake.overlays
│   ├── _additions.nix               # Custom packages added to pkgs
│   ├── _modifications.nix           # Overrides to existing nixpkgs packages
│   ├── _stable-packages.nix         # Exposes nixpkgs-stable as pkgs.stable
│   └── _unstable-packages.nix       # Exposes nixpkgs-unstable as pkgs.unstable
│
├── shells/                          # Isolated development environments (self-registering)
├── cachix/                          # Cachix binary cache declarations
├── pkgs/                            # Custom package definitions
├── bin/                             # Utility shell scripts
└── .sops.yaml                       # SOPS age key configuration
```

> **Note:** The repository tree is the authoritative reference for current hosts, modules, shells, and features. Browse the directories themselves for precise contents. Files prefixed with `_` are leaf files consumed by their parent module and are intentionally excluded from import-tree discovery.

---

## Usage

- ### <ins>First Install on a New Machine</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

```bash
# 1. Boot NixOS installer, partition drives, mount at /mnt

# 2. Get a shell with git
nix-shell -p git

# 3. Clone the repository
mkdir -p /mnt/home/temhr
cd /mnt/home/temhr && git clone https://github.com/temhr/nixlab.git

# 4. Generate hardware config and save to hardware/
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix ~/nixlab/hardware/<model>.nix

# 5. Create hardware module, host configuration, and home configuration
#    (see "Adding a New Host" section below)

# 6. First build (requires git commit for flake to see new files)
cd ~/nixlab
git add -A
git commit -m "Add <hostname> configuration"

sudo nixos-rebuild boot \
  --flake .#<hostname> \
  --extra-experimental-features "nix-command flakes"

sudo reboot
```

</details>

- ### <ins>Daily Commands</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

```bash
# Rebuild and switch current host
sudo nixos-rebuild switch --flake ~/nixlab

# Rebuild a specific host
sudo nixos-rebuild switch --flake ~/nixlab#<hostname>

# Test configuration without switching
sudo nixos-rebuild test --flake ~/nixlab#<hostname>

# Update all flake inputs
nix flake update --flake ~/nixlab

# Update a single input
nix flake update <input-name> --flake ~/nixlab

# Format all nix files
nix fmt ~/nixlab

# Run checks (formatting, dead code, merge conflicts)
nix flake check ~/nixlab

# Validate all host configurations (CI-style)
nix run ~/nixlab#build-all

# Enter a dev shell
nix develop ~/nixlab#<shell-name>

# Show all flake outputs
nix flake show ~/nixlab

# Garbage collect old generations
sudo nix-collect-garbage --delete-older-than 7d

# Ping watchdog management
watchdog status         # Show current state and recent logs
sudo watchdog off       # Inhibit reboot watchdog this boot
sudo watchdog on        # Re-enable watchdog
sudo watchdog reset     # Clear backoff exponent back to cycle 0

# Manage encrypted secrets
sops sops/<service>.yaml                    # Edit encrypted secrets
sops -d sops/<service>.yaml                 # View decrypted (read-only)

# Update all secrets after modifying .sops.yaml
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
  nix-shell -p sops --run "sops updatekeys sops/*.yaml"
```

</details>

- ### <ins>Adding a New Host</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Adding a new host requires creating three self-registering files and one metadata entry.

#### 1. Add host metadata to `flake/parts/_hosts-meta.nix`

```nix
<hostname> = mkHostMeta {
  address = "192.168.0.XXX";
  ethIface = "enp0s31f6";            # Find with: ip link
  wifiIface = "wlp3s0";              # Find with: ip link (omit if no wifi)
  hostId = "XXXXXXXX";               # Generate with: head -c 8 /etc/machine-id
  nixpkgsInput = "nixpkgs-stable";   # or "nixpkgs-unstable"
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

Choose the appropriate profile(s) for the machine role:

```nix
{ self, ... }: {
  flake.nixosConfigurations.<hostname> = self.lib.mkHost {
    name = "<hostname>";
    modules = [
      self.nixosModules.hardw--<model>
      self.nixosModules.hosts--<hostname>
      self.nixosModules.hosts--profl--base      # required for all hosts
      self.nixosModules.hosts--profl--desktop   # add for desktop/laptop machines
      # self.nixosModules.hosts--profl--nas     # add instead for NAS/server machines
      # service modules this host specifically needs:
      self.nixosModules.servc--glance-nixlab
      self.nixosModules.nsops--glance
    ];
  };

  flake.nixosModules.hosts--<hostname> = { config, pkgs, ... }: {
    nixlab.mainUser = "temhr";
    services.displayManager.autoLogin.user = config.nixlab.mainUser;
    gShells.DE = "plasma6";   # only needed if using profile-desktop

    # App toggles (options provided by profile-desktop's app modules)
    blender.enable = true;
    steam.enable = true;
    libreoffice.enable = true;

    # Service configuration
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

#### 4. Create home configuration `home/<username>/<hostname>.nix`

```nix
{ self, ... }: {
  flake.homeModules.<username>-<hostname> = { config, lib, pkgs, ... }: {
    imports = [
      self.homeModules.common-global
      # optional user feature modules
    ];

    home = {
      username = "<username>";
      homeDirectory = "/home/<username>";
      stateVersion = "24.11";
    };
  };
}
```

#### 5. Deploy the new host

```bash
cd ~/nixlab
git add -A
nix flake check
sudo nixos-rebuild switch --flake .#<hostname>
```

</details>

- ### <ins>Adding a New Service Module</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Service modules follow the self-exporting pattern and live in `modules/nixos/<service>/`. Secrets are managed separately in the `sops/` directory.

#### 1. Create the module `modules/nixos/<service>/default.nix`

```nix
{ ... }: {
  flake.nixosModules.servc--<service>-nixlab = { config, lib, pkgs, ... }:
  let
    cfg = config.services.<service>-nixlab;
  in {
    options.services.<service>-nixlab = {
      enable = lib.mkEnableOption "<service>";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/<service>";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      secretsEnvFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.services.<service> = {
        description = "<Service> daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.<service>}/bin/<service> --port ${toString cfg.port}";
          User = "<service>";
          Group = "<service>";
          EnvironmentFile = lib.mkIf (cfg.secretsEnvFile != null) cfg.secretsEnvFile;
        };
      };

      users.users.<service> = { isSystemUser = true; group = "<service>"; };
      users.groups.<service> = {};

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
    };
  };
}
```

#### 2. (Optional) Add secrets support in `sops/`

**`sops/<service>.nix`:**
```nix
{ ... }: {
  flake.nixosModules.nsops--<service> = { config, lib, ... }:
  let
    cfg = config.services.<service>-nixlab;
  in {
    options.services.<service>-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./<service>.yaml;
    };

    config = lib.mkIf cfg.enable {
      sops.secrets."<service>/env" = {
        sopsFile = cfg.secretsFile;
        owner = "<service>";
        restartUnits = ["<service>.service"];
      };

      services.<service>-nixlab.secretsEnvFile =
        config.sops.secrets."<service>/env".path;
    };
  };
}
```

Then encrypt your secrets file: `sops sops/<service>.yaml`

#### 3. Use the module in a host

```nix
# In hosts/<hostname>.nix modules = [...]:
self.nixosModules.servc--<service>-nixlab
self.nixosModules.nsops--<service>     # if secrets are needed

# In the host's config section:
services.<service>-nixlab = {
  enable = true;
  port = 9090;
  openFirewall = true;
  dataDir = "/data/<service>";
};
```

#### 4. Validate and deploy

```bash
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
