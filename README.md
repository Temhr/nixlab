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

nixlab uses **flake-parts** as its orchestration layer, structured around the **Dendritic Pattern**.

<details>
<summary>Design overview <i>(click to expand)</i></summary>
<p></p>

## flake-parts

[flake-parts](https://github.com/hercules-ci/flake-parts) is a NixOS community library that structures flake outputs as composable modules called **parts**. Instead of one monolithic `outputs = { ... }` function, each concern lives in its own file and declares exactly what it contributes. The `flake.nix` root becomes a thin entry point:

```nix
outputs = inputs @ { flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" ... ];
    imports = [
      ./flake/parts/overlays.nix
      ./flake/parts/packages.nix
      ./flake/parts/devshells.nix
      ./flake/parts/checks.nix
      ./flake/parts/nixos.nix
    ];
  };
```

Inside parts, `perSystem` replaces `forAllSystems` and is called automatically for each supported system. Architecture-independent outputs (nixosConfigurations, overlays, modules) use the `flake.` namespace.

## The Dendritic Pattern

The Dendritic Pattern organises NixOS configuration around **features rather than hostnames**. The name comes from the branching, self-similar structure where each part of the config is independent and composable.

The key shift is in the **axis of composition**: instead of asking _"what does this machine need?"_ and building outward from a hostname, you ask _"which features does this machine require?"_ and assemble inward from capabilities. Host files become pure **feature manifests** — short declarations of intent — rather than containers of inline configuration.

In practice:
- Shared behaviour lives in `*/common/global/` (universal) or `*/common/optional/` (selectable)
- Host files express selections: `steam.enable = true`, `incus.enable = true`
- Adding a new host means writing a short manifest pointing at existing feature modules
- Changing a feature happens in one place and propagates to every host that selects it

## Part files

Each file under `flake/parts/` owns a slice of the flake's outputs:

| Part file | Responsibility | Output namespace |
|---|---|---|
| `overlays.nix` | Package modifications and channel switching | `flake.` |
| `packages.nix` | Custom packages and formatter | `perSystem` |
| `devshells.nix` | Isolated development environments | `perSystem` |
| `checks.nix` | Pre-commit hooks and build validation | `perSystem` |
| `nixos.nix` | All NixOS host configurations | `flake.` |

</details>

---

# Repository Layout

```
nixlab/
│
├── flake.nix                  # Thin root — delegates entirely to flake/parts/
├── flake.lock                 # Version-pinned input revisions
│
├── flake/
│   └── parts/                 # flake-parts orchestration modules
│
├── hardware/                  # Machine-level hardware configurations
│   ├── common/
│   │   ├── global/            # Applied to all machines unconditionally
│   │   └── optional/          # Selectable per host
│   └── *.nix                  # Per-device configs (from nixos-generate-config)
│
├── hosts/                     # System-level NixOS configurations
│   ├── common/
│   │   ├── global/            # Applied to all hosts unconditionally
│   │   └── optional/          # Selectable features (imported by host manifests)
│   └── *.nix                  # Per-host feature manifests
│
├── home/                      # User-level Home Manager configurations
│   ├── common/
│   │   ├── files/             # Managed dotfiles and scripts
│   │   ├── global/            # Applied to all users unconditionally
│   │   └── optional/          # Selectable user features
│   └── <user>/                # Per-user, per-host overrides
│
├── modules/                   # Reusable encapsulated modules (exported as flake outputs)
│   ├── nixos/                 # System-level service and application modules
│   └── home-manager/          # User-level modules
│
├── overlays/                  # nixpkgs modifications and pinned channel overlays
│
├── pkgs/                      # Custom package definitions
│
├── shells/                    # Isolated development environments
│
├── lib/                       # Helper Nix code and configuration templates
│
├── secrets/                   # sops-encrypted secret files
│
├── cachix/                    # Cachix binary cache declarations
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

1. Add the hostname to the `hosts` attrset in `flake/parts/nixos.nix`
2. Run `nixos-generate-config` on the new machine, save result to `hardware/<model>.nix`
3. Create `hosts/<hostname>.nix` — import hardware config, select optional features
4. Create `home/<user>/<hostname>.nix` — user-level config for the new host
5. Run `nix flake check` to validate, then deploy: `sudo nixos-rebuild switch --flake .#<hostname>`

</details>
