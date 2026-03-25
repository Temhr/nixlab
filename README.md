# nixlab

Modular NixOS configuration for Linux laptops, desktops, and homelab servers. Adapted from [Misterio77's nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) with inspiration from [EmergentMind](https://www.youtube.com/watch?v=YHm7e3f87iY&list=PLAWyx2BxU4OyERRTbzNAaRHK08DQ0DD_l&index=1), [8bitbuddhism](https://code.8bitbuddhism.com/aires/nix-configuration), and many others.

- [Nix Ecosystem Terminology](#nix-ecosystem-terminology)
- [Architecture](#architecture)
- [Repository Layout](#repository-layout)
- [Usage](#usage)

---

# Nix Ecosystem Terminology

<details>
<summary>Common terms and definitions <i>(click to expand)</i></summary>
<p></p>

- **Nix Language**: A domain-specific, declarative, pure, functional, lazily evaluated, dynamically typed programming language used to describe software builds and system configurations
  - **Nix Expressions**: Code written in the Nix language that defines how to build packages, assemble dependencies, or configure systems. Expressions evaluate to values and can be composed as functions
  - **Nix Values**: Immutable data types produced by evaluating Nix Expressions. Values are evaluated lazily (only when needed) and produce type errors at evaluation time
  - **Derivations**: Low-level build instructions generated from Expressions. A Derivation precisely specifies all inputs, dependencies, environment variables, and build steps required to produce a reproducible build output
- **Nix Package Manager**: A command-line toolset with an atomic update model that:
  > 1. evaluates Expressions into Derivations
  > 2. builds Packages from Derivations
  > 3. manages the Nix Store (including dependency tracking, garbage collection, and atomic upgrades/rollbacks)
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

# Architecture

nixlab uses **flake-parts** as its orchestration layer, structured around the **Dendritic Pattern**, with all module wiring done through a named registry rather than filesystem paths.

<details>
<summary>Design overview <i>(click to expand)</i></summary>
<p></p>

## flake-parts

[flake-parts](https://github.com/hercules-ci/flake-parts) is a NixOS community library that structures flake outputs as composable modules called **parts**. Instead of one monolithic `outputs = { ... }` function, each concern lives in its own file and declares exactly what it contributes. The `flake.nix` root is a thin entry point that delegates entirely to `flake/parts/` via [import-tree](https://github.com/vic/import-tree), which auto-discovers all part files:

```nix
outputs = inputs @ { flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    imports = [ (inputs.import-tree ./flake/parts) ];
  };
```

Adding a new part file under `flake/parts/` requires no changes to `flake.nix` — import-tree discovers it automatically.

Inside parts, `perSystem` replaces `forAllSystems` and is called automatically for each supported system. Architecture-independent outputs (nixosConfigurations, overlays, modules) use the `flake.` namespace.

## The Dendritic Pattern

The Dendritic Pattern organises NixOS configuration around **features rather than hostnames**. The name comes from the branching, self-similar structure where each part of the config is independent and composable.

The key shift is in the **axis of composition**: instead of asking _"what does this machine need?"_ and building outward from a hostname, you ask _"which features does this machine require?"_ and assemble inward from capabilities. Host files become pure **feature manifests** — short declarations of intent — rather than containers of inline configuration.

In practice:
- Shared behaviour lives in `*/common/global/` (universal) or `*/common/optional/` (selectable)
- Host files express feature selections: `steam.enable = true`, `incus.enable = true`
- Adding a new host means writing a short manifest and registering it — no knowledge of filesystem layout required
- Changing a feature happens in one place and propagates to every host that selects it

## Module registry

All modules are registered by stable name in `flake/parts/nixos.nix` and `flake/parts/overlays.nix`. Host and home files reference modules by name via `self.nixosModules.*` and `self.homeModules.*` rather than by filesystem path. Files can be freely moved or renamed without breaking any configuration — the name is the contract, not the path.

```nix
# hosts wire by name, not path
nixace = mkHost { modules = [
  self.nixosModules.hw-zb17g4-p5
  self.nixosModules.hosts-global
  self.nixosModules.hosts-optional
  self.nixosModules.services
  self.nixosModules.nixace
]; };
```

## Part files

Each file under `flake/parts/` owns a slice of the flake's outputs:

| Part file | Responsibility | Output namespace |
|---|---|---|
| `overlays.nix` | Package overlays, nixosModules registry, homeModules registry | `flake.` |
| `packages.nix` | Custom packages and formatter (`alejandra`) | `perSystem` |
| `devshells.nix` | Isolated development environments | `perSystem` |
| `checks.nix` | Pre-commit hooks and build validation | `perSystem` |
| `nixos.nix` | NixOS module registry and all host configurations | `flake.` |

</details>

---

# Repository Layout

```
nixlab/
├── flake.nix                  # Thin root — delegates to flake/parts/ via import-tree
├── flake.lock                 # Version-pinned input revisions
│
├── flake/
│   └── parts/                 # flake-parts orchestration (auto-discovered by import-tree)
│       ├── overlays.nix       # Overlays + nixosModules registry + homeModules registry
│       ├── packages.nix       # Custom packages + alejandra formatter
│       ├── devshells.nix      # All development shell environments
│       ├── checks.nix         # Pre-commit hooks (alejandra, deadnix, merge-conflict check)
│       └── nixos.nix          # NixOS module registry + all nixosConfigurations
│
├── hardware/                  # Machine-level hardware configurations
│   ├── common/
│   │   ├── global/            # Applied to all machines unconditionally
│   │   └── optional/          # Selectable hardware modules (GPU drivers, extra drives)
│   └── *.nix                  # Per-device generated configs (nixos-generate-config)
│
├── hosts/                     # System-level NixOS configurations
│   ├── common/
│   │   ├── global/            # Applied to all hosts unconditionally
│   │   │                      # (audio, bluetooth, boot, display, locale, network,
│   │   │                      #  nix settings, ssh, power management, users...)
│   │   └── optional/          # Selectable feature modules
│   │                          # (development, education, games, media, observability,
│   │                          #  productivity, virtualisation, graphical shells...)
│   └── *.nix                  # Per-host feature manifests (no imports block — registry handles wiring)
│
├── home/                      # User-level Home Manager configurations
│   ├── common/
│   │   ├── files/             # Managed dotfiles and scripts (bash config, themes)
│   │   ├── global/            # Applied to all users unconditionally
│   │   │                      # (git, fastfetch, folders, virt-manager, utilities...)
│   │   └── optional/          # Selectable user features (bash symlinks...)
│   └── temhr/                 # Per-user, per-host configurations
│       └── *.nix              # One file per host — user feature selections only
│
├── modules/                   # Reusable encapsulated modules (exported via flake registry)
│   ├── nixos/                 # System-level service and application modules
│   │                          # (bookstack, comfyui, glance, gotosocial, grafana,
│   │                          #  home-assistant, homepage, loki, node-red, ollama,
│   │                          #  prometheus, syncthing, waydroid, wiki-js, zola)
│   └── home-manager/          # User-level modules (browsers, terminal emulators)
│
├── overlays/                  # nixpkgs modifications and pinned channel overlays
│                              # Exposes: pkgs.unstable, pkgs.stable, pkgs.ollamaPkgs
│                              # Includes: ollama-p5000, comfyui-p5000, open-webui fixes
│
├── pkgs/                      # Custom package definitions
│
├── shells/                    # Isolated development environments
│                              # (default, mesa, python, repast4py, rust, security, web, minimal)
│
├── secrets/                   # sops-encrypted secret files
│
├── cachix/                    # Cachix binary cache declarations
│                              # (cuda-maintainers, ghostty, nix-community)
│
├── bin/                       # Utility shell scripts
│
└── .sops.yaml                 # sops age key configuration
```

> The repository tree is the authoritative reference for current hosts, modules, shells, and features. The layout above describes purpose and convention — browse the directories themselves for precise contents.

---

# Usage

<details>
<summary>Installation and daily commands <i>(click to expand)</i></summary>
<p></p>

## First install on a new machine

```bash
# 1. Boot NixOS installer, partition drives, mount at /mnt

# 2. Get a shell with git
nix-shell -p git

# 3. Clone the repo
mkdir -p /mnt/home/temhr
cd /mnt/home/temhr && git clone https://github.com/temhr/nixlab.git

# 4. Generate hardware config and save into hardware/
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix ~/nixlab/hardware/<model>.nix

# 5. First build
sudo nixos-rebuild boot \
  --flake github:temhr/nixlab#<hostname> \
  --extra-experimental-features "nix-command flakes"

sudo reboot
```

## Daily commands

```bash
# Rebuild and switch current host
sudo nixos-rebuild switch --flake /home/temhr/nixlab

# Rebuild a specific host
sudo nixos-rebuild switch --flake /home/temhr/nixlab#<hostname>

# Update all flake inputs
nix flake update --flake /home/temhr/nixlab

# Update a single input
nix flake update <input-name> --flake /home/temhr/nixlab

# Format all nix files
nix fmt /home/temhr/nixlab

# Run checks (formatting, dead code, merge conflicts)
nix flake check /home/temhr/nixlab

# Enter a dev shell
nix develop /home/temhr/nixlab#<shell-name>

# Show all flake outputs
nix flake show /home/temhr/nixlab
```

## Adding a new host

1. Create `hosts/<hostname>.nix` — feature selections only, no imports block, no hostname declaration
2. Create `home/temhr/<hostname>.nix` — user config using `self.homeModules.*` imports
3. Generate hardware config: `nixos-generate-config`, save to `hardware/<model>.nix`
4. Register in `flake/parts/nixos.nix`:
   - Add `hw-<model>` and `<hostname>` entries to `flake.nixosModules`
   - Add `<hostname>` to `flake.nixosConfigurations` listing which named modules it composes
5. Register in `flake/parts/overlays.nix`:
   - Add `temhr-<hostname>` to `flake.homeModules`
6. Run `nix flake check` to validate, then deploy: `sudo nixos-rebuild switch --flake .#<hostname>`

</details>
