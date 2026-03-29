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

nixlab uses **flake-parts** as its orchestration layer, structured around the **Dendritic Pattern** and a **self-exporting module schema** where every file registers its own outputs directly into the flake — no central registry required.

<details>
<summary>Design overview <i>(click to expand)</i></summary>
<p></p>

## flake-parts

[flake-parts](https://github.com/hercules-ci/flake-parts) is a NixOS community library that structures flake outputs as composable modules called **parts**. Instead of one monolithic `outputs = { ... }` function, each concern lives in its own file and declares exactly what it contributes. The `flake.nix` root is a thin entry point that uses [import-tree](https://github.com/vic/import-tree) to auto-discover all part files across multiple directories:

```nix
outputs = inputs @ { flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    imports = [
      (inputs.import-tree ./flake/parts)
      (inputs.import-tree ./modules)
      (inputs.import-tree ./overlays)
      (inputs.import-tree ./shells)
      (inputs.import-tree ./hardware)
      (inputs.import-tree ./hosts/flake)
      (inputs.import-tree ./hosts/common/global/flake)
      (inputs.import-tree ./hosts/common/optional/flake)
    ];
  };
```

Adding a new self-exporting file to any discovered directory requires no changes to `flake.nix` — import-tree discovers it automatically.

Inside parts, `perSystem` is called automatically for each supported system. Architecture-independent outputs (nixosConfigurations, overlays, modules) use the `flake.` namespace.

## The Dendritic Pattern

The Dendritic Pattern organises NixOS configuration around **features rather than hostnames**. The name comes from the branching, self-similar structure where each part of the config is independent and composable.

The key shift is in the **axis of composition**: instead of asking _"what does this machine need?"_ and building outward from a hostname, you ask _"which features does this machine require?"_ and assemble inward from capabilities. Host files become pure **feature manifests** — short declarations of intent — rather than containers of inline configuration.

In practice:
- Shared behaviour lives in `*/common/global/` (universal) or `*/common/optional/` (selectable)
- Host files express feature selections: `steam.enable = true`, `incus.enable = true`
- Adding a new host means writing two small files — no knowledge of filesystem layout required
- Changing a feature happens in one place and propagates to every host that selects it

## Self-Exporting Module Schema

Every file in this flake is a **flake-parts module** — a function that takes `{ self, inputs, ... }` and registers its own outputs directly into the flake. There is no central registry. Each file is fully self-sufficient:

```nix
# modules/nixos/glance/default.nix
{ ... }: {
  flake.nixosModules.services.glance = { config, lib, pkgs, ... }: {
    options.services.glance = { ... };
    config = lib.mkIf cfg.enable { ... };
  };
}
```

```nix
# hosts/flake/nixace-flake.nix
{ self, ... }: {
  flake.nixosModules.hosts.nixace = { ... }: {
    networking.hostName = "nixace";
    imports = [ (import ../nixace.nix) ];
  };

  flake.nixosConfigurations.nixace = self.lib.mkHost {
    modules = [
      self.nixosModules.hardware.c-global
      self.nixosModules.hosts.nixace
      self.nixosModules.services.glance
      # ...
    ];
  };
}
```

Files reference each other exclusively by **output name** — never by filesystem path. This means files can be freely moved or renamed without breaking any consumer. The name is the contract, not the path.

A single file can also emit **multiple related outputs** — for example, a service module can register both a `flake.nixosModules.services.*` entry and a `perSystem.packages.*` entry for a co-located custom package, with the NixOS module referencing the package via `self'`.

## nixosModules namespace

All NixOS modules are registered under `flake.nixosModules` using a nested namespace that groups them by concern. This produces a readable tree in `nix flake show`:

```
nixosModules
├───hosts--c-global
├───hosts--c-optional
├───hosts--nixace
├───hosts--nixsun
├───hosts--nixtop
├───hosts--nixvat
├───hosts--nixzen
├───hw--c-global
├───hw--c-optional--driver-nvidia
├───hw--zb15g2-k1
├───hw--zb17g1-k3
├───hw--zb17g1-k4
├───hw--zb17g2-k5
├───hw--zb17g4-p5
├───secrets--bookstack
├───secrets--grafana
├───svc--bookstack-nixlab
├───svc--comfyui-extensions
├───svc--comfyui-models
├───svc--comfyui-p5000
├───svc--glance-nixlab
├───svc--gotosocial-nixlab
├───svc--grafana-nixlab
├───svc--home-assistant-nixlab
├───svc--homepage-nixlab
├───svc--loki-nixlab
├───svc--node-red-nixlab
├───svc--ollama-cpu
├───svc--ollama-p5000
├───svc--prometheus-nixlab
├───svc--syncthing-nixlab
├───svc--waydroid-nixlab
├───svc--wiki-js-nixlab
├───svc--zola-nixlab
├───sys--auto-backup-phone-media
├───sys--cachix
└───sys--home-manager-config
```

## Remaining flake/parts/ files

A small number of concerns remain in `flake/parts/` as conventional flake-parts files rather than self-registering modules:

| File | Responsibility | Output namespace |
|---|---|---|
| `lib.nix` | `mkHost` host assembly helper + `home-manager-config` module | `flake.lib`, `flake.nixosModules.system` |
| `overlays.nix` | Bridge for overlay registration during migration | `flake.overlays` |
| `packages.nix` | Custom packages and `alejandra` formatter | `perSystem` |
| `checks.nix` | Pre-commit hooks and build validation | `perSystem` |

## Secrets management

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) using age encryption. Each service that requires secrets has a dedicated encrypted YAML file in `secrets/` and a corresponding secrets module in `hosts/common/optional/flake/` that declares which keys to decrypt and when. Secrets modules accept a `*File` path option rather than a plaintext string — the decrypted runtime path is passed in from the host file via `config.sops.secrets.<KEY>.path`.

The `nixlab.mainUser` option (declared in `hosts/common/global/users/main-user.nix`) provides the primary system username to all modules, replacing hardcoded usernames throughout the codebase.

</details>

---

# Repository Layout

```
nixlab/
├── flake.nix                     # Thin root — delegates to directories via import-tree
├── flake.lock                    # Version-pinned input revisions
│
├── flake/                        # Orchestration-level flake-parts configs (auto-discovered)
│   └── parts/
│       ├── lib.nix               # mkHost helper + home-manager-config module
│       ├── overlays.nix          # Package overlays
│       ├── packages.nix          # Custom packages + alejandra formatter
│       └── checks.nix            # Pre-commit hooks (alejandra, deadnix, merge-conflict)
│
├── hardware/                     # Machine-level hardware configs (auto-discovered)
│   ├── common/
│   │   ├── global/               # Applied to all machines unconditionally
│   │   └── optional/             # Selectable hardware modules (GPU drivers)
│   └── <model>.nix               # Per-device, feature manifest
│
├── hosts/                        # System-level NixOS configurations
│   ├── common/
│   │   ├── global/               # Applied to all hosts unconditionally
│   │   │   ├── users/            # Declares nixlab.mainUser option
│   │   │   └── flake/            # Self-registers nixosModules.hosts.c-global
│   │   └── optional/             # Selectable feature modules
│   │       └── flake/            # Self-registers nixosModules.hosts.c-optional
│   ├── flake/                    # Self-registering, per-host wrappers
│   └── <hostname>.nix            # Per-host, feature manifest — pure option selections, no imports
│
├── home/                         # User-level Home Manager configurations
│   ├── common/
│   │   ├── files/                # Managed dotfiles and scripts (bash config, themes)
│   │   ├── global/               # Applied to all users unconditionally
│   │   └── optional/             # Selectable user features (browsers, terminal emulators)
│   └── temhr/                    # Per-user, host feature selections
│
├── modules/                      # Reusable self-exporting service modules (auto-discovered)
│   ├── nixos/                    # System-level sservice modules
│   └── home-manager/             # User-level modules
│
├── overlays/                     # nixpkgs modifications and pinned channel overlays
│   ├── default.nix               # Self-registers all overlays into flake.overlays
│   └── _*.nix                    # Leaf overlay functions — imported by default.nix
│
├── shells/                       # Isolated development environments (auto-discovered)
├── secrets/                      # sops-encrypted secret files (one per service)
├── cachix/                       # Cachix binary cache declarations
├── bin/                          # Utility shell scripts
└── .sops.yaml                    # sops age key configuration
```

> The repository tree is the authoritative reference for current hosts, modules, shells, and features. The layout above describes purpose and convention — browse the directories themselves for precise contents.
>
> Files prefixed with `_` (e.g. `_internals/`, `_services.nix`) are leaf files consumed by their parent module and are excluded from import-tree discovery intentionally.

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

1. Create `hosts/<hostname>.nix` — feature selections only, no imports block, no hostname declaration. Set `nixlab.mainUser` to the primary user for this machine.
2. Create `home/temhr/<hostname>.nix` — user config referencing `self.homeModules.*`.
3. Generate hardware config: `nixos-generate-config`, save to `hardware/<model>.nix`.
4. Create `hardware/flake/<model>-flake.nix` to self-register the hardware module:
   ```nix
   { ... }: {
     flake.nixosModules.hardware.<model> = import ../<model>.nix;
   }
   ```
5. Create `hosts/flake/<hostname>-flake.nix` to self-register the host module and configuration:
   ```nix
   { self, ... }: {
     flake.nixosModules.hosts.<hostname> = { ... }: {
       networking.hostName = "<hostname>";
       imports = [ (import ../<hostname>.nix) ];
     };
     flake.nixosConfigurations.<hostname> = self.lib.mkHost {
       modules = [
         self.nixosModules.hardware.c-global
         self.nixosModules.hardware.c-optional
         self.nixosModules.hardware.<model>
         self.nixosModules.hosts.c-global
         self.nixosModules.hosts.c-optional
         self.nixosModules.system.cachix
         # add only the services this host actually uses:
         self.nixosModules.services.<n>
         self.nixosModules.hosts.<hostname>
       ];
     };
   }
   ```
6. Add `temhr-<hostname>` to `flake.homeModules` in the home modules bridge file.
7. Commit all new files (`git add -A`) — Nix only copies git-tracked files into the store.
8. Run `nix flake check` to validate, then deploy: `sudo nixos-rebuild switch --flake .#<hostname>`

## Adding a new service module

1. Create `modules/nixos/<service>/default.nix` as a self-registering flake-parts module:
   ```nix
   { ... }: {
     flake.nixosModules.services.<service> = { config, lib, pkgs, ... }: {
       options.services.<service> = {
         enable = lib.mkEnableOption "<service>";
         # ...
       };
       config = lib.mkIf config.services.<service>.enable {
         # ...
       };
     };
   }
   ```
2. Place any leaf files imported by the module in `modules/nixos/<service>/_internals/` so import-tree does not attempt to discover them directly.
3. Add `self.nixosModules.services.<service>` to the modules list of any host that uses it in its `hosts/flake/<hostname>-flake.nix`.
4. Run `nix flake check` to validate.

</details>
