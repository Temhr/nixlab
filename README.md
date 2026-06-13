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
  - [Host Build Flow](#host-build-flow)
  - [Profile Composition](#profile-composition)
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

nixlab uses **flake-parts**, the **Dendritic Pattern**, and a **self-exporting module schema** — every file registers its own outputs directly into the flake, no central registry required.

- ### <ins>flake-parts Orchestration</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

[flake-parts](https://github.com/hercules-ci/flake-parts) structures flake outputs as composable modules. Each concern lives in its own file and declares exactly what it contributes. `flake.nix` is a thin entry point that uses [import-tree](https://github.com/vic/import-tree) to auto-discover all part files:

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
- New files auto-register — no changes to `flake.nix` required
- `perSystem` called automatically per supported system
- Architecture-independent outputs use the `flake.` namespace
- `_`-prefixed files are excluded from auto-discovery

</details>

- ### <ins>The Dendritic Pattern</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Organizes configuration around **features rather than hostnames**. Instead of asking _"what does this machine need?"_, you ask _"which features does it require?"_ and assemble from capabilities.

- **Shared behaviour** lives in domain-grouped modules under `hosts/common/` — `core/` for universals, `desktop/`, `apps/`, `automation/`, `hardware/`
- **Profiles** (`profile-base`, `profile-desktop`, `profile-nas`) compose those modules into role-appropriate bundles
- **Host files** are pure feature manifests — a profile selection plus declarative option enables
- **Changing a feature** happens in one place and propagates to every host that uses it

</details>

- ### <ins>Self-Exporting Module Schema</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Every file is a **flake-parts module** — a function taking `{ self, inputs, ... }` that registers its own outputs directly into the flake. No central registry:

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
- Files reference each other by **output name** (`self.nixosModules.*`) — never by path
- Files can be freely moved or renamed without breaking consumers
- A single file can emit multiple related outputs
- The name is the contract, not the path

</details>

- ### <ins>nixosModules Namespace</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

All NixOS modules register under `flake.nixosModules` using a double-dash naming convention that encodes a two-level hierarchy in a flat namespace:

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

Run `nix flake show` to see the complete output tree. Representative sample:

```
├───nixosConfigurations
│   ├───nixace, nixtop, nixsun, nixvat, nixzen  # desktops
│   └───nixnas1, nixnas2                        # NAS
├───nixosModules
│   ├───hardw--zb17g4-p5          # one per machine model
│   ├───hosts--profl--base        # profiles
│   ├───hosts--core--networking   # universal core
│   ├───hosts--deskt--firefox     # desktop layer
│   ├───hosts--apps--games        # app toggles
│   ├───hosts--autom--backup-home # automation
│   ├───hosts--debug--diagnose    # opt-in only
│   ├───servc--glance-nixlab      # service modules
│   └───nsops--glance             # secrets wiring
```

</details>

- ### <ins>Central Orchestration Files</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

A small number of concerns live in `flake/parts/` as conventional flake-parts files rather than self-registering modules:

| File | Responsibility | Output namespace |
|------|---------------|------------------|
| `lib.nix` | Defines `mkHost` helper; reads `_hosts-meta.nix`; wires common modules (sops-nix, home-manager, overlays) | `flake.lib` |
| `_hosts-meta.nix` | Static `hostsMeta` attrset containing per-host metadata: IP addresses, network interfaces, system architecture, nixpkgs input selection | *(imported by `lib.nix`)* |
| `options-home.nix` | Declares `flake.homeModules` as a mergeable `lazyAttrsOf` option for collision-free contributions | `flake.homeModules` |
| `nixpkgs.nix` | Configures the default `pkgs` instance for all `perSystem` blocks with `allowUnfree = true` and applies all overlays | `perSystem._module.args.pkgs` |
| `packages.nix` | Imports custom packages from `pkgs/` directory | `perSystem.packages` |
| `checks.nix` | Pre-commit hooks (alejandra, deadnix, merge-conflict guards) and formatter configuration | `perSystem.checks`, `perSystem.formatter` |
| `apps.nix` | Defines the `build-all` app that validates all `nixosConfiguration` outputs | `perSystem.apps.build-all` |

**Key features:**
- **Per-host nixpkgs selection**: different hosts can use different nixpkgs inputs (stable, unstable, pinned)
- **Centralized overlays**: applied uniformly across all configurations
- **Metadata-driven networking**: IPs and interface names centralized in `_hosts-meta.nix`

</details>

- ### <ins>Secrets Management</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) using age encryption, centralized in `sops/`:

- **Encrypted secrets**: per-service `.yaml` files (`sops/glance.yaml`, `sops/ssh-keys.yaml`, etc.)
- **Secret modules**: `sops/<service>.nix` declares which keys to decrypt and wires them to services, registering as `flake.nixosModules.nsops--<service>`
- **File-based options**: service modules accept `*File` path options, never plaintext strings
- **Runtime decryption**: paths available via `config.sops.secrets.<KEY>.path`

Each service gets a paired `<service>.nix` (module declaration) and `<service>.yaml` (encrypted secrets) under `sops/`. See [Repository Layout](#repository-layout) for the full structure.

**SSH Keys:** Stored encrypted in `sops/ssh-keys.yaml`, decrypted at boot to `/run/secrets/ssh_key_*`. Symlinks at `~/.ssh/id_*` enable interactive use; systemd services reference `/run/secrets/` directly.

**Secret patterns used in this repo:**

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

How configuration flows from `flake.nix` through every layer to a built NixOS system.

- ### <ins>Host Build Flow</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

`nixos-rebuild` evaluates `flake.nixosConfigurations.<hostname>`, built by `self.lib.mkHost` (defined in `flake/parts/lib.nix`). The NixOS module system merges all layers — resolving options and `lib.mkIf` guards — into a single system configuration passed to `nixpkgs.lib.nixosSystem`.

```
nixosConfigurations.nixace
└── self.lib.mkHost { name = "nixace"; modules = [...]; }
    │
    │  (lib.nix injects automatically)
    ├── nixpkgs instance  ← per-host selection from _hosts-meta.nix
    ├── sops-nix module
    ├── overlays
    ├── hostMeta          ← IP, interfaces, etc.
    │
    │  (declared in modules = [...])
    ├── hardw--zb17g4-p5          # hardware
    ├── hosts--nixace             # host identity + feature selections
    ├── hosts--profl--base        # see Profile Composition below
    ├── hosts--profl--desktop     # see Profile Composition below
    ├── servc--bookstack-nixlab   # host-specific services
    ├── nsops--bookstack
    ├── servc--ollama
    └── nsops--ollama
```

</details>

- ### <ins>Profile Composition</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Profiles are pure `imports = [...]` lists — no new configuration, just role-appropriate module bundles.

```
hosts--profl--base
├── hosts--core--boot-loader
├── hosts--core--display-manager
├── hosts--core--home-manager-config
├── hosts--core--journald
├── hosts--core--locale             # en_CA, America/Toronto
├── hosts--core--monitoring         # Prometheus + Loki + Grafana
├── hosts--core--networking         # NetworkManager, wifi via sops templates
├── hosts--core--nginx              # active only if nginx is enabled
├── hosts--core--nix                # flakes, registry, store optimisation
├── hosts--core--open-ssh           # key-only auth, no root login
├── hosts--core--sops
├── hosts--core--system
├── hosts--core--users              # nixlab.mainUser option + HM dispatch
├── hosts--core--utilities
├── hosts--autom--nix-gc
├── hosts--autom--nixos-upgrade
├── hosts--autom--nixlab-gpull
├── servc--homepage-nixlab
└── nsops--ssh-keys


hosts--profl--desktop
├── hosts--apps--development        # blender, godot, vscodium (toggles)
├── hosts--apps--education          # anki (toggle)
├── hosts--apps--games              # steam (toggle)
├── hosts--apps--media              # obs, spotify, vlc (toggles)
├── hosts--apps--productivity       # calibre, libreoffice, logseq (toggles)
├── hosts--apps--virtualizations    # incus, quickemu, wine, etc. (toggles)
├── hosts--deskt--cache-tmpfs       # browser cache → tmpfs
├── hosts--deskt--firefox           # system Firefox with policies + extensions
├── hosts--deskt--flatpak           # Flathub + auto-update
├── hosts--deskt--gui-shells        # GNOME / Plasma6 selector
├── hosts--deskt--ignore-lid        # lid-close + sleep inhibit
├── hosts--hardw--audio             # PipeWire + ALSA + PulseAudio compat
├── hosts--hardw--bluetooth
├── hosts--hardw--power-management  # HDD APM, AHCI LPM, sysctl I/O tuning
├── hosts--autom--backup-home       # nightly rsync home backup
├── hosts--autom--flake-update      # nightly flake.lock update + push
└── hosts--autom--ping-watchdog     # internet watchdog, exponential backoff


hosts--profl--nas
└── hosts--autom--backup-phone-media  # move phone photos from Syncthing share
```

Desktop hosts (`nixace`, `nixtop`, `nixsun`, `nixvat`, `nixzen`) import `base` + `desktop`. NAS hosts (`nixnas1`, `nixnas2`) import `base` + `nas`.

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
│   ├── common/
│   │   ├── global/                  # Applied to all machines unconditionally
│   │   └── optional/                # Selectable hardware modules (GPU drivers, extra mounts)
│   └── <model>.nix                  # Per-device hardware configuration + module registration
│
├── hosts/                           # System-level NixOS configurations (self-registering)
│   ├── <hostname>.nix               # nixosConfiguration + hosts--<hostname> module declaration
│   └── common/
│       ├── profile-*.nix            # hosts--profl--*: module compositions
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

> Files prefixed with `_` are leaf files consumed by their parent and excluded from import-tree discovery.

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

Three self-registering files and one metadata entry.

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

Service modules live in `modules/nixos/<service>/`. Secrets are managed separately in `sops/`.

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
