# nixlab

Modular NixOS configuration for Linux laptops, desktops, and homelab servers. Built on the **Dendritic Pattern** using **flake-parts** for composable, self-registering modules where every file declares its own outputs.

Adapted from [Misterio77's nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) with inspiration from [EmergentMind](https://www.youtube.com/watch?v=YHm7e3f87iY&list=PLAWyx2BxU4OyERRTbzNAaRHK08DQ0DD_l&index=1), [Vimjoyer](https://www.youtube.com/@vimjoyer), and the broader NixOS community. Written almost entirely by Claude.

---

**Table of Contents**
- [Nix Ecosystem Terminology](#nix-ecosystem-terminology)
- [Architecture & Import Flow](#architecture--import-flow)
  - [Entry Point & Discovery](#entry-point--discovery)
  - [Central Orchestration Files](#central-orchestration-files)
  - [The Dendritic Pattern](#the-dendritic-pattern)
  - [Self-Exporting Module Schema](#self-exporting-module-schema)
  - [Module Namespace & Naming](#module-namespace--naming)
  - [Profile Composition](#profile-composition)
  - [Host Build Flow](#host-build-flow)
  - [Secrets Management](#secrets-management)
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

## Architecture & Import Flow

nixlab uses **flake-parts** and the **Dendritic Pattern**: configuration is organized around features rather than hostnames, with every file self-registering its own outputs — no central registry required.

- ### <ins>Entry Point & Discovery</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

`flake.nix` is a pure delegation layer. [flake-parts](https://github.com/hercules-ci/flake-parts) structures outputs as composable modules; [import-tree](https://github.com/vic/import-tree) auto-discovers every `.nix` file in each top-level directory. Each discovered file contributes to the shared `flake.*` / `perSystem.*` namespaces — adding a new file requires no changes to `flake.nix`. Files prefixed with `_` are leaf imports consumed by their parent and excluded from discovery.

```nix
outputs = inputs @ { flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    imports = [
      (inputs.import-tree ./flake)    # → orchestration (lib, nixpkgs, checks, apps)
      (inputs.import-tree ./hardware) # → hardw--* nixosModules
      (inputs.import-tree ./home)     # → homeModules.*
      (inputs.import-tree ./hosts)    # → hosts--* nixosModules + nixosConfigurations
      (inputs.import-tree ./modules)  # → servc--* nixosModules
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

A small number of concerns live in `flake/parts/` as conventional flake-parts files rather than self-registering modules:

| File | Responsibility | Output |
|------|---------------|--------|
| `lib.nix` | `mkHost` constructor; reads `_hosts-meta.nix`; injects nixpkgs, sops-nix, overlays, hostMeta | `flake.lib` |
| `_hosts-meta.nix` | Per-host metadata: IPs, interfaces, architecture, nixpkgs input selection | *(imported by `lib.nix`)* |
| `options-home.nix` | Declares `flake.homeModules` as a mergeable `lazyAttrsOf` option | `flake.homeModules` |
| `nixpkgs.nix` | Configures `pkgs` for all `perSystem` blocks (`allowUnfree` + overlays) | `perSystem._module.args.pkgs` |
| `checks.nix` | Pre-commit hooks (alejandra, deadnix, merge-conflict guards) + formatter | `perSystem.checks` |
| `apps.nix` | `build-all` app — validates every `nixosConfiguration` | `perSystem.apps.build-all` |
| `packages.nix` | Imports `pkgs/` into perSystem | `perSystem.packages` |

</details>

- ### <ins>The Dendritic Pattern</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Instead of configuring each machine individually, you assemble it from capabilities. **Features** > **Profiles** > **Hosts** — branching from general to specific: _"which features does this machine require?"_

1. **Feature Modules** — standalone services (`modules/`), secrets (`nsops/`), or modules domain-grouped by shared behaviour
    - `hosts/common/` — `core/`, `desktop/`, `apps/`, `automation/`, `hardware/`
1. **Profiles** — (`profile-base`, ...) composed from **Feature Modules** into role-appropriate bundles
1. **Host manifest** — a selection of **Profiles**, **Feature Modules**, option enables, plus assignment of the **Hardware** and **Home** manifests
1. **nixosConfigurations.[hostname]** fully built system output — **Host** plus **Overlays**, **Home**, and **dev shells** wired in automatically
   by `mkHost` in `lib.nix`

</details>

- ### <ins>Self-Exporting Module Schema</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Every file is a flake-parts module that registers its own outputs directly. No central registry; the name is the only stable contract — files can be freely moved without breaking consumers.

```nix
# modules/nixos/glance/default.nix
{ ... }: {
  flake.nixosModules.servc--glance-nixlab = { config, lib, pkgs, ... }: {
    options.services.glance-nixlab = { enable = lib.mkEnableOption "glance"; ... };
    config = lib.mkIf cfg.enable { ... };
  };
}
```

```nix
# hosts/nixace.nix  — one file, two outputs
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
    nixlab.mainUser = "temhr";
    gShells.DE = "plasma6";
    blender.enable = true;
    steam.enable = true;
    # feature selections only — no imports, no inline service configs
  };
}
```

</details>

- ### <ins>Module Namespace & Naming</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

All modules register under `flake.nixosModules`. The double-dash convention encodes a two-level hierarchy in a flat namespace — all cross-file references use `self.nixosModules.*`, never filesystem paths.

| Prefix | Layer |
|--------|-------|
| `hardw--` | Physical machine hardware |
| `hosts--<hostname>` | Host identity + feature selections |
| `hosts--profl--` | Profile compositions (base, desktop, nas) |
| `hosts--core--` | Universal modules (all hosts) |
| `hosts--deskt--` | Desktop-only modules |
| `hosts--apps--` | Toggleable application modules |
| `hosts--autom--` | Scheduled tasks and automation |
| `hosts--hardw--` | Shared hardware concerns |
| `hosts--debug--` | Opt-in diagnostics (never in any profile) |
| `servc--` | Self-hosted service modules |
| `nsops--` | sops-nix secret wiring modules |

```
# nix flake show (abbreviated)
├───nixosConfigurations
│   ├───nixace, nixnas1, nixnas2, nixsun, nixtop, nixvat, nixzen
├───nixosModules
│   ├───hardw--zb17g4-p5
│   ├───hosts--profl--base, hosts--profl--desktop, hosts--profl--nas
│   ├───hosts--core--nix, hosts--core--networking, hosts--core--monitoring, ...
│   ├───hosts--deskt--gui-shells, hosts--deskt--firefox, ...
│   ├───hosts--apps--development, hosts--apps--games, ...
│   ├───hosts--autom--backup-home, hosts--autom--ping-watchdog, ...
│   ├───hosts--debug--diagnose
│   ├───servc--glance-nixlab, servc--grafana-nixlab, ...
│   └───nsops--glance, nsops--ssh-keys, ...
```

Run `nix flake show` for the complete tree.

</details>

- ### <ins>Profile Composition</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Profiles are pure `imports = [...]` lists — no new configuration, just role-appropriate module bundles. Desktop hosts import `base` + `desktop`; NAS hosts import `base` + `nas`.

```
hosts--profl--base
├── hosts--core--boot-loader       # systemd-boot, generation limit
├── hosts--core--nix               # flakes, registry, store optimisation
├── hosts--core--networking        # NetworkManager, firewall, wifi via sops templates
├── hosts--core--open-ssh          # sshd, key-only auth, no root login
├── hosts--core--users             # nixlab.mainUser option, accounts, HM dispatch
├── hosts--core--monitoring        # Prometheus + Loki + Grafana
├── hosts--core--utilities         # system-wide CLI tools
├── hosts--...
├── servc--homepage-nixlab         # Homepage dashboard
└── nsops--ssh-keys                # GitHub SSH key decryption

hosts--profl--desktop
├── hosts--apps--{development,education,games,media,productivity,virtualizations}
├── hosts--deskt--{firefox,flatpak,gui-shells,ignore-lid,cache-tmpfs}
├── hosts--hardw--{audio,bluetooth,power-management}
└── hosts--autom--{backup-home,flake-update,ping-watchdog}

hosts--profl--nas
└── hosts--autom--backup-phone-media
```

</details>

- ### <ins>Host Build Flow</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

`nixos-rebuild` evaluates `flake.nixosConfigurations.<hostname>`, built by `self.lib.mkHost` in `flake/parts/lib.nix`. The NixOS module system merges all layers — resolving options and `lib.mkIf` guards — into a single configuration passed to `nixpkgs.lib.nixosSystem`.

```
nixosConfigurations.nixace
└── self.lib.mkHost { name = "nixace"; modules = [...]; }
    │
    │  (injected automatically by lib.nix for every host)
    ├── nixpkgs    ← selected per-host via _hosts-meta.nix
    ├── sops-nix   ← inputs.sops-nix.nixosModules.sops-nix
    ├── overlays   ← all overlays applied to pkgs
    ├── hostMeta   ← IP, interfaces, etc.
    │
    │  (declared in the host's modules = [...] list)
    ├── hardw--zb17g4-p5         # filesystems, kernel modules
    ├── hosts--nixace            # feature selections
    ├── hosts--profl--base       # universal profile
    ├── hosts--profl--desktop    # desktop profile
    ├── servc--bookstack-nixlab  # service module
    └── nsops--bookstack         # secrets wiring
```

</details>

- ### <ins>Secrets Management</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) using age encryption, centralized in `sops/`:

- **Encrypted secrets**: per-service `.yaml` files committed to the repo
- **Secret modules**: `sops/<service>.nix` declares which keys to decrypt and wires paths to services, registering as `nsops--<service>`
- **File-based options**: service modules accept `*File` path options — never plaintext strings
- **Runtime decryption**: paths available via `config.sops.secrets.<KEY>.path`

```
sops/
├── <service>.nix   # registers nsops--<service> module
├── <service>.yaml  # encrypted secrets
├── ssh-keys.{nix,yaml}
└── networking.{nix,yaml}
```

**SSH keys:** Private keys stored encrypted in `sops/ssh-keys.yaml`, decrypted at boot to `/run/secrets/ssh_key_*`. Symlinks at `~/.ssh/id_*` enable interactive use; systemd services reference `/run/secrets/` directly.

**Secret patterns used in this repo:**

1. **Environment file** (`glance`, `homepage`): Single secret with KEY=value lines, loaded via `EnvironmentFile`
2. **Discrete secrets** (`grafana`, `bookstack`): Individual secrets declared with `lib.genAttrs`, each accessible separately
3. **Oneshot builder** (`node-red`): Systemd oneshot assembles the env file from multiple secrets at runtime
4. **File passthrough** (`home-assistant`): Entire decrypted secret installed as `secrets.yaml` in the data directory
5. **Shared secrets** (`networking`): WiFi credentials used across multiple hosts
6. **SSH keys** (`ssh-keys`): Dual access via `/run/secrets/` (services) and `~/.ssh/` symlinks (interactive)

```bash
sops sops/<service>.yaml       # create or edit
sops -d sops/<service>.yaml    # view decrypted (read-only)

# Re-key all files after modifying .sops.yaml
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
  nix-shell -p sops --run "sops updatekeys sops/*.yaml"
```

| Secret Type | Encrypted | Decrypted | Interactive |
|-------------|-----------|-----------|-------------|
| Service secrets | `sops/<service>.yaml` | `/run/secrets/SERVICE_*` | — |
| SSH keys | `sops/ssh-keys.yaml` | `/run/secrets/ssh_key_*` | `~/.ssh/id_*` (symlink) |

</details>

---

## Repository Layout

```
nixlab/
├── flake.nix                        # Thin root — delegates to directories via import-tree
├── flake.lock                       # Version-pinned input revisions
│
├── flake/                           # Orchestration-level flake-parts configurations
│   └── parts/
│       ├── _hosts-meta.nix          # Static per-host metadata: IPs, interfaces, nixpkgs
│       ├── apps.nix                 # build-all app: validates every nixosConfiguration
│       ├── checks.nix               # Pre-commit hooks (alejandra, ...) + formatter
│       ├── lib.nix                  # mkHost constructor; reads hostsMeta; wires modules + overlays
│       ├── nixpkgs.nix              # Configs pkgs instance (allowUnfree + overlays) for perSystem
│       ├── options-home.nix         # Declares flake.homeModules as mergeable lazyAttrsOf option
│       └── packages.nix             # Imports pkgs/ into perSystem.packages
│
├── hardware/                        # Machine-level hardware configurations
│   ├── common/
│   │   ├── global/                  # Applied to all machines unconditionally
│   │   └── optional/                # Selectable hardware modules (GPU drivers, extra mounts)
│   └── <model>.nix                  # Per-device hardware configuration + module registration
│
├── home/                            # User-level Home Manager configurations
│   ├── common/
│   │   ├── files/                   # Managed dotfiles and scripts
│   │   ├── global/                  # Applied to all users unconditionally
│   │   └── optional/                # Selectable user-package modules
│   └── <username>/                  # User environment for specific hosts
│       └── <hostname>.nix 
│
├── hosts/                           # System-level NixOS configurations
│   ├── common/
│   │   ├── core/                    # Universal modules
│   │   │   └── _users/              # nixlab.mainUser option + user account definitions
│   │   ├── desktop/                 # Desktop-only modules
│   │   ├── hardware/                # Physical hardware modules
│   │   ├── apps/                    # Toggleable software modules
│   │   ├── automation/              # Scheduled tasks
│   │   ├── debug/                   # Opt-in only — never included in any profile
│   │   └── profile-*.nix            # hosts--profl--*: module compositions
│   └── <hostname>.nix               # nixosConfiguration + hosts--<hostname> modules 
│
├── modules/                         # Reusable self-exporting service modules
│   ├── home-manager/                # User-level service modules
│   └── nixos/                       # System-level service modules (servc--*)
│       └── <service>/
│           └── default.nix
│
├── sops/                            # Centralized secrets management
│   ├── <service>.nix                # Secret module declarations (nsops--*)
│   └── <service>.yaml               # Encrypted secrets per module
│
├── overlays/                        # nixpkgs modifications and channel pinning
│   ├── default.nix                  # Self-registers all overlays into flake.overlays
│   ├── _additions.nix               # Custom packages added to pkgs
│   ├── _modifications.nix           # Overrides to existing nixpkgs packages
│   ├── _stable-packages.nix         # Exposes nixpkgs-stable as pkgs.stable
│   └── _unstable-packages.nix       # Exposes nixpkgs-unstable as pkgs.unstable
│
├── shells/                          # Isolated development environments
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
  address = "10.0.0.XXX";
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
    nixlab.mainUser = "temhr";
    services.displayManager.autoLogin.user = config.nixlab.mainUser;
    gShells.DE = "plasma6";   # only needed if using profile-desktop

    blender.enable = true;
    steam.enable = true;
    libreoffice.enable = true;

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
    ];

    home = {
      username = "<username>";
      homeDirectory = "/home/<username>";
      stateVersion = "24.11";
    };
  };
}
```

#### 5. Deploy

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
  let cfg = config.services.<service>-nixlab; in {
    options.services.<service>-nixlab = {
      enable = lib.mkEnableOption "<service>";
      port = lib.mkOption { type = lib.types.port; default = 8080; };
      listenAddress = lib.mkOption { type = lib.types.str; default = "127.0.0.1"; };
      dataDir = lib.mkOption { type = lib.types.str; default = "/var/lib/<service>"; };
      openFirewall = lib.mkOption { type = lib.types.bool; default = false; };
      secretsEnvFile = lib.mkOption { type = lib.types.nullOr lib.types.path; default = null; };
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

#### 2. (Optional) Add secrets support `sops/<service>.nix`

```nix
{ ... }: {
  flake.nixosModules.nsops--<service> = { config, lib, ... }:
  let cfg = config.services.<service>-nixlab; in {
    config = lib.mkIf cfg.enable {
      sops.secrets."<service>/env" = {
        sopsFile = ./<service>.yaml;
        owner = "<service>";
        restartUnits = ["<service>.service"];
      };
      services.<service>-nixlab.secretsEnvFile =
        config.sops.secrets."<service>/env".path;
    };
  };
}
```

Then encrypt: `sops sops/<service>.yaml`

#### 3. Use in a host

```nix
# modules = [...]:
self.nixosModules.servc--<service>-nixlab
self.nixosModules.nsops--<service>

# config:
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
