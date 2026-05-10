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
<summary>A NixOS community library that structures flake outputs as composable modules called **parts**.  <i>(click to expand)</i></summary>
<p></p>

With [flake-parts](https://github.com/hercules-ci/flake-parts), instead of one monolithic `outputs = { ... }` function, each concern lives in its own file and declares exactly what it contributes.

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
      (inputs.import-tree ./sops)     # Secret modules (nsops--*) auto-discovered here
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
<summary>The Dendritic Pattern organizes NixOS configuration around **features rather than hostnames**.  <i>(click to expand)</i></summary>
<p></p>

The name comes from the branching, self-similar structure where each part of the config is independent and composable. 

**The key shift** is in the axis of composition: instead of asking _"what does this machine need?"_ and building outward from a hostname, you ask _"which features does this machine require?"_ and assemble inward from capabilities.

In practice:
- **Shared behaviour** lives in `*/common/global/` (applied universally) or `*/common/optional/` (selectable features)
- **Host files** become pure feature manifests — short declarations like `services.glance.enable = true`
- **Adding a new host** means writing three small files (host, home, hardware) — no deep knowledge of filesystem layout required
- **Changing a feature** happens in one place and propagates to every host that selects it

</details>

- ### <ins>Self-Exporting Module Schema</ins>

<details>
<summary>Almost every file in this flake is a **flake-parts module**.  <i>(click to expand)</i></summary>
<p></p>

A **flake-parts module** is a function that takes `{ self, inputs, ... }` and registers its own outputs directly into the flake. There is no central registry. Each file is fully self-sufficient:

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
      self.homeModules.temhr-nixace
      self.nixosModules.servc--glance-nixlab
      self.nixosModules.systm--home-manager-config
      # ...
    ];
  };
  
  flake.nixosModules.hosts--nixace = { ... }: {
    networking.hostName = "nixace";
    nixlab.mainUser = "temhr";
    # feature selections only
  };
}
```

**Key principles:**
- Files reference each other exclusively by **output name** (`self.nixosModules.*`) — never by filesystem path
- Files can be freely moved or renamed without breaking consumers
- A single file can emit multiple related outputs (e.g., a service module + its custom package)
- The name is the contract, not the path

</details>

- ### <ins>nixosModules Namespace</ins>

<details>
<summary>All NixOS modules are registered under `flake.nixosModules` using a nested namespace that groups them by concern.  <i>(click to expand)</i></summary>
<p></p>

Module names use a double-dash separator to create a readable hierarchy: 

**Naming convention:**
- `hardw--<identifier>`: Hardware configurations
- `hosts--<identifier>`: Host configurations and feature selections
- `servc--<identifier>`: Service modules
- `systm--<identifier>`: System-level utilities
- `nsops--<identifier>`: NixOps-related modules

**Example output tree:**
```
├───nixosConfigurations
│   ├───nixace: NixOS configuration
│   ├───nixsun: NixOS configuration
│   └───...
├───nixosModules
│   ├───hardw--c-global: NixOS module
│   ├───hardw--c-optional--driver-nvidia: NixOS module
│   ├───hardw--zb17g4-p5: NixOS module
│   ├───hosts--c-global: NixOS module
│   ├───hosts--c-optional--games: NixOS module
│   ├───hosts--nixace: NixOS module
│   ├───servc--glance-nixlab: NixOS module
│   ├───servc--grafana-nixlab: NixOS module
│   ├───systm--home-manager-config: NixOS module
│   └───...
```

Run `nix flake show` to see the complete module tree.

</details>

- ### <ins>Central Orchestration Files</ins>

<details>
<summary>A small number of concerns remain in `flake/parts/` as conventional flake-parts files rather than self-registering modules.  <i>(click to expand)</i></summary>
<p></p>

Additionally, the `sops/` directory contains self-registering secret modules that are auto-discovered alongside service modules.

| File | Responsibility | Output namespace |
|------|---------------|------------------|
| `lib.nix` | Defines `mkHost` helper; reads `_hosts-meta.nix`; wires common modules (sops-nix, home-manager, overlays) | `flake.lib` |
| `_hosts-meta.nix` | Static `hostsMeta` attrset containing per-host metadata: IP addresses, network interfaces, system architecture, nixpkgs input selection, and service lists | *(imported by `lib.nix`)* |
| `options-home.nix` | Declares `flake.homeModules` as a mergeable `lazyAttrsOf` option for collision-free contributions | `flake.homeModules` |
| `nixpkgs.nix` | Configures the default `pkgs` instance for all `perSystem` blocks with `allowUnfree = true` and applies all overlays | `perSystem._module.args.pkgs` |
| `packages.nix` | Imports custom packages from `pkgs/` directory | `perSystem.packages` |
| `checks.nix` | Pre-commit hooks (alejandra, deadnix, merge-conflict guards) and formatter configuration | `perSystem.checks`, `perSystem.formatter` |
| `apps.nix` | Defines the `build-all` app that validates all `nixosConfiguration` outputs | `perSystem.apps.build-all` |

**Secrets modules in `sops/`**: Self-registering modules (e.g., `secrets-glance.nix`, `secrets-grafana.nix`) are auto-discovered by import-tree and register as `flake.nixosModules.nsops--<service>`.

**Key orchestration features:**
- **Per-host nixpkgs selection**: `_hosts-meta.nix` allows different hosts to use different nixpkgs inputs (stable, unstable, or pinned versions)
- **Centralized overlays**: All four overlays are applied uniformly across all configurations
- **Metadata-driven networking**: IP addresses and interface names are centralized for easier network management

</details>

- ### <ins>Secrets Management</ins>

<details>
<summary>Secrets are managed with sops-nix using age encryption.  <i>(click to expand)</i></summary>
<p></p>

All [sops-nix](https://github.com/Mic92/sops-nix) secrets-related files are centralized in the `sops/` directory:

- **Encrypted secrets**: Each service has a dedicated `.yaml` file (e.g., `sops/glance.yaml`, `sops/grafana.yaml`)
- **Secret modules**: Corresponding `secrets-<service>.nix` files declare which keys to decrypt and wire them to services
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
├── glance.yaml              # Encrypted secrets for glance
├── secrets-glance.nix       # Declares nsops--glance module
├── grafana.yaml             # Encrypted secrets for grafana
├── secrets-grafana.nix      # Declares nsops--grafana module
└── networking.yaml          # Shared networking secrets (wifi credentials)
```

**Example secret module** (`sops/secrets-glance.nix`):
```nix
{...}: {
  flake.nixosModules.nsops--glance = { config, lib, ... }:
  let
    cfg = config.services.glance-nixlab;
  in {
    options.services.glance-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./glance.yaml;
      description = "Path to sops-encrypted secrets file";
    };

    config = lib.mkIf cfg.enable {
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";
      
      sops.secrets.GLANCE_ENV = {
        sopsFile = cfg.secretsFile;
        owner = "glance";
        restartUnits = ["glance.service"];
      };

      # Wire decrypted secret to service
      services.glance-nixlab.secretsEnvFile = 
        config.sops.secrets.GLANCE_ENV.path;
    };
  };
}
```

**Common secret management patterns:**

The codebase demonstrates several approaches to handling secrets:

1. **Simple environment file** (`glance`, `homepage`): Single `SERVICENAME_ENV` secret containing KEY=value lines, loaded via `EnvironmentFile`

2. **Multiple discrete secrets** (`grafana`, `bookstack`): Individual secrets declared with `lib.genAttrs`, each accessible separately in the service config

3. **Dedicated oneshot service** (`node-red`): A systemd oneshot service builds the environment file from multiple secrets at runtime

4. **YAML file passthrough** (`home-assistant`): The entire decrypted secret is installed as `secrets.yaml` in the service's data directory

5. **Shared secrets** (`networking`): Common credentials (WiFi SSID/password) used across multiple hosts

**The `nixlab.mainUser` option** (declared in `hosts/common/global/users/main-user.nix`) provides the primary system username to all modules, eliminating hardcoded usernames throughout the configuration.

**Encrypting and managing secrets:**

```bash
# Encrypt a new or existing secrets file
sops sops/<service>.yaml

# Edit encrypted secrets
sops sops/<service>.yaml

# Rotate age keys (after generating new keys)
sops updatekeys sops/<service>.yaml

# View decrypted content (does not modify)
sops -d sops/<service>.yaml
```

The `.sops.yaml` file in the repository root defines which age keys can decrypt which secrets. Each host must have its age key (typically stored at `/var/lib/sops-nix/key.txt`) listed in `.sops.yaml` to decrypt secrets assigned to it.

</details>

---

## Repository Layout

```
nixlab/
├── flake.nix                   # Thin root — delegates to directories via import-tree
├── flake.lock                  # Version-pinned input revisions
│
├── flake/                      # Orchestration-level flake-parts configs
│   └── parts/
│       ├── _hosts-meta.nix     # Static per-host metadata: IPs, interfaces, services, nixpkgs
│       ├── apps.nix            # build-all app: validates every nixosConfiguration
│       ├── checks.nix          # Pre-commit hooks (alejandra, deadnix, guards) + formatter
│       ├── lib.nix             # mkHost constructor; reads hostsMeta; wires modules + overlays
│       ├── nixpkgs.nix         # Configs pkgs instance (allowUnfree + overlays) for perSystem
│       ├── options-home.nix    # Declares flake.homeModules as mergeable lazyAttrsOf option
│       └── packages.nix        # Imports pkgs/ into perSystem.packages
│
├── hardware/                   # Machine-level hardware configs (self-registering)
│   ├── common/
│   │   ├── global/             # Applied to all machines unconditionally
│   │   └── optional/           # Selectable hardware modules (GPU drivers, extra mounts)
│   └── <model>.nix             # Per-device hardware configuration + module registration
│
├── hosts/                      # System-level NixOS configurations (self-registering)
│   ├── common/
│   │   ├── global/             # Applied to all hosts unconditionally
│   │   │   └── users/          # Declares nixlab.mainUser option and user accounts
│   │   └── optional/           # Selectable feature modules (games, media, virtualization)
│   │       └── networking/     # Network-related configurations
│   └── <hostname>.nix          # Per-host feature manifest + nixosConfiguration registration
│
├── home/                       # User-level Home Manager configurations
│   ├── common/
│   │   ├── files/              # Managed dotfiles and scripts (bash config, themes)
│   │   ├── global/             # Applied to all users unconditionally
│   │   └── optional/           # Selectable user-package modules (browsers, terminals)
│   └── <username>/             # Per-user, per-host home-manager modules
│       └── <hostname>.nix      # User environment for specific host
│
├── modules/                    # Reusable self-exporting service modules
│   ├── nixos/                  # System-level service modules
│   │   └── <service>/
│   │       └── default.nix     # Module definition + self-registration
│   └── home-manager/           # User-level service modules
│
├── sops/                       # Centralized secrets management
│   ├── <service>.yaml          # Encrypted secrets per service (e.g., glance.yaml)
│   ├── secrets-<service>.nix   # Secret module declarations (e.g., secrets-glance.nix)
│   └── networking.yaml         # Shared secrets (wifi credentials, etc.)
│
├── overlays/                   # nixpkgs modifications and channel pinning
│   ├── default.nix             # Self-registers all overlays into flake.overlays
│   ├── _additions.nix          # Custom packages added to pkgs
│   ├── _modifications.nix      # Overrides to existing nixpkgs packages
│   ├── _stable-packages.nix    # Exposes nixpkgs-stable as pkgs.stable
│   └── _unstable-packages.nix  # Exposes nixpkgs-unstable as pkgs.unstable
│
├── shells/                     # Isolated development environments (self-registering)
├── cachix/                     # Cachix binary cache declarations
├── pkgs/                       # Custom package definitions
├── bin/                        # Utility shell scripts
└── .sops.yaml                  # SOPS age key configuration
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
sudo nixos-rebuild switch --flake /home/temhr/nixlab

# Rebuild a specific host
sudo nixos-rebuild switch --flake /home/temhr/nixlab#<hostname>

# Test configuration without switching
sudo nixos-rebuild test --flake /home/temhr/nixlab#<hostname>

# Update all flake inputs
nix flake update --flake /home/temhr/nixlab

# Update a single input
nix flake update <input-name> --flake /home/temhr/nixlab

# Format all nix files
nix fmt /home/temhr/nixlab

# Run checks (formatting, dead code, merge conflicts)
nix flake check /home/temhr/nixlab

# Validate all host configurations (CI-style)
nix run /home/temhr/nixlab#build-all

# Enter a dev shell
nix develop /home/temhr/nixlab#<shell-name>

# Show all flake outputs
nix flake show /home/temhr/nixlab

# Garbage collect old generations
sudo nix-collect-garbage --delete-older-than 7d
```

</details>

- ### <ins>Adding a New Host</ins>

<details><summary><i>(click to expand)</i></summary>
<p></p>
  
Adding a new host requires creating three self-registering files and one metadata entry:

#### 1. Add host metadata to `flake/parts/_hosts-meta.nix`

```nix
<hostname> = mkHostMeta {
  address = "192.168.0.XXX";
  ethIface = "enp0s31f6";       # Find with: ip link
  wifiIface = "wlp3s0";         # Find with: ip link
  hostId = "XXXXXXXX";          # Generate with: head -c 8 /etc/machine-id
  nixpkgsInput = "nixpkgs-stable";  # or "nixpkgs-unstable"
  services = ["glance" "grafana" "prometheus"];  # Services this host runs
};
```

#### 2. Create hardware module `hardware/<model>.nix`

```nix
{ self, ... }: {
  flake.nixosModules.hardw--<model> = { config, lib, pkgs, ... }: {
    imports = [
      self.nixosModules.hardw--c-global
      # Add optional hardware modules as needed:
      # self.nixosModules.hardw--c-optional--driver-nvidia
      # self.nixosModules.hardw--c-optional--mounts-extra
    ];

    # Paste output from nixos-generate-config here:
    boot.initrd.availableKernelModules = [ ... ];
    boot.initrd.kernelModules = [ ... ];
    boot.kernelModules = [ ... ];
    boot.extraModulePackages = [ ... ];

    fileSystems."/" = { ... };
    # ... additional filesystems ...

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
      # Core modules (required)
      self.nixosModules.hosts--<hostname>
      self.nixosModules.hosts--c-global
      self.nixosModules.hardw--<model>
      self.homeModules.<username>-<hostname>
      self.nixosModules.systm--cachix
      
      # Optional feature modules
      self.nixosModules.hosts--c-optional--games
      self.nixosModules.hosts--c-optional--media
      
      # Service modules (only those this host uses)
      self.nixosModules.servc--glance-nixlab
      self.nixosModules.servc--grafana-nixlab
    ];
  };

  flake.nixosModules.hosts--<hostname> = { config, lib, pkgs, ... }: {
    networking.hostName = "<hostname>";
    nixlab.mainUser = "<username>";
    
    # Feature selections (no imports, no inline configs)
    services.glance.enable = true;
    services.grafana.enable = true;
    # ... other declarative options ...
  };
}
```

#### 4. Create home configuration `home/<username>/<hostname>.nix`

```nix
{ self, ... }: {
  flake.homeModules.<username>-<hostname> = { config, lib, pkgs, ... }: {
    imports = [
      self.homeModules.common-global
      # Optional user feature modules
      self.homeModules.common-optional--browsers
      self.homeModules.common-optional--terminals
    ];

    home = {
      username = "<username>";
      homeDirectory = "/home/<username>";
      stateVersion = "25.11";  # Match your NixOS version
    };

    # User-specific configurations
    programs.git.userEmail = "user@example.com";
  };
}
```

#### 5. Deploy the new host

```bash
cd /home/temhr/nixlab

# Stage all new files (flakes only see git-tracked files)
git add -A

# Validate the configuration
nix flake check

# Build and deploy
sudo nixos-rebuild switch --flake .#<hostname>
```

</details>

- ### <ins>Adding a New Service Module</ins>

<details>
<summary><i>(click to expand)</i></summary>
<p></p>

Service modules follow the self-exporting pattern and live in `modules/nixos/<service>/`. Secrets are managed separately in the `sops/` directory.

#### 1. Create service module

```bash
mkdir -p modules/nixos/<service>
```

#### 2. Create `modules/nixos/<service>/default.nix`

```nix
{ ... }: {
  flake.nixosModules.servc--<service>-nixlab = { config, lib, pkgs, ... }: 
  let
    cfg = config.services.<service>;
  in {
    options.services.<service> = {
      enable = lib.mkEnableOption "<service>";
      
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port to listen on";
      };
      
      # Accept secrets via file path (populated by sops module)
      secretsEnvFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to environment file with secrets";
      };
    };

    config = lib.mkIf cfg.enable {
      # Service implementation
      systemd.services.<service> = {
        description = "<Service> daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        
        serviceConfig = {
          ExecStart = "${pkgs.<service>}/bin/<service>";
          User = "<service>";
          Group = "<service>";
          # Load secrets from file (if provided)
          EnvironmentFile = lib.mkIf (cfg.secretsEnvFile != null) 
            cfg.secretsEnvFile;
        };
      };

      # Create user/group
      users.users.<service> = {
        isSystemUser = true;
        group = "<service>";
      };
      users.groups.<service> = {};

      # Open firewall
      networking.firewall.allowedTCPPorts = [ cfg.port ];
    };
  };
}
```

#### 3. (Optional) Add secrets support in `sops/`

If the service needs secrets, create **two files** in the `sops/` directory:

**`sops/<service>.yaml`** (encrypted secrets):
```yaml
# Encrypt with: sops sops/<service>.yaml
api_key: your-api-key-here
secret_key: your-secret-here
```

**`sops/secrets-<service>.nix`** (self-registering secret module):
```nix
{...}: {
  flake.nixosModules.nsops--<service> = { config, lib, ... }:
  let
    cfg = config.services.<service>;
  in {
    options.services.<service>.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./service>.yaml;
      description = "Path to sops-encrypted secrets file";
    };

    config = lib.mkIf cfg.enable {
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";
      
      sops.secrets."<service>/env" = {
        sopsFile = cfg.secretsFile;
        owner = config.users.users.<service>.name;
        group = config.users.groups.<service>.name;
        restartUnits = ["<service>.service"];
      };

      # Wire decrypted secret to service
      services.<service>.secretsEnvFile = 
        config.sops.secrets."<service>/env".path;
    };
  };
}
```

#### 4. Use the module in a host

Add to `hosts/<hostname>.nix` module list:

```nix
flake.nixosConfigurations.<hostname> = self.lib.mkHost {
  name = "<hostname>";
  modules = [
    # ... existing modules ...
    self.nixosModules.servc--<service>-nixlab
    # If service needs secrets, also add:
    self.nixosModules.nsops--<service>
  ];
};
```

Enable in the host's configuration section:

```nix
flake.nixosModules.hosts--<hostname> = { ... }: {
  services.<service> = {
    enable = true;
    port = 9090;
  };
};
```

#### 5. Validate and deploy

```bash
# Check for issues
nix flake check

# Deploy to specific host
sudo nixos-rebuild switch --flake .#<hostname>
```

</details>

## Acknowledgments

- [Misterio77](https://github.com/Misterio77/nix-starter-configs) - Base configuration structure
- [EmergentMind](https://www.youtube.com/@EmergentMind) - Educational video series
- [Vimjoyer](https://www.youtube.com/@vimjoyer) - Educational video series
- The NixOS community for extensive documentation and support
- Little, by little, by a lot: rewritten almost entirely with Claude
