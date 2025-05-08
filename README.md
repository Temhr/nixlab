Nix implementation for my Linux laptops, desktops, and homelab servers. Adapted from [Misterio77's standard starter config](https://github.com/Misterio77/nix-starter-configs) with inspiration from [EmergentMind](https://www.youtube.com/watch?v=YHm7e3f87iY&list=PLAWyx2BxU4OyERRTbzNAaRHK08DQ0DD_l&index=1)'s youtube tutorials, [8bitbuddhism](https://code.8bitbuddhism.com/aires/nix-configuration), and many others.

- [Nix Ecosystem Terminology](#nix-ecosystem-terminology)
- [Nixlab Features](#nixlab-features)
- [Implementations](#implementations)
- [Repository Layout](#repository-layout)

# Nix Ecosystem Terminology
<details>
<summary>Definitions of terms used</summary>
- Nix Language: a domain-specific, declarative, pure, functional, lazy-evaluated, dynamically typed, language
  - Nix values: data types that are immutable, can be whole **expressions** themselves, are only computed when needed, and type-error detected at evaluation
- Nix Expressions: **Nix lang** code (functions) that describes how to build packages or configure systems
  - Derivations: the backend build task; specifies all inputs, dependencies, and build steps of an **expression**
- Nix Packages Collection (Nixpkgs): a large repository of **Nix expressions**
- Nix Store: complex abstractions of immutable file system data (software packages, dependencies, etc.)
- Nix Package Manager: a command-line toolset, with an atomic update model, that:
  1) evaluates **expressions** into **derivations**
  2) builds packages from **derivations** 
  3) manages the **Nix Store** (handles dependencies, ensures reproducibility), where packages are kept
- NixOS: Linux distro that has a system configuration entirely built with Nix
</details>

# Nixlab Features
Contains
- **Cachix**: cache service of prebuilt binaries; speeds installs, avoids compilations 
- **Flakes**: a schema for writing, referencing, and sharing **Nix expressions**
  - consists of a filesystem tree with a flake.nix file in root directory; specifies:
    - metadata about the flake
    - inputs (**expressions**, pkg repos, other flakes) which are taken as dependencies
    - outputs (pkg defs, dev-envs, NixOS configs, modules, etc.) are whatever the flake produces; ultimately given as **Nix values**, evaluated by the **Nix package manager**
  - updates **Nix package manager**'s CLI with the new/experimental commands
  - version-pinning of pkgs and dependencies via flake.lock file (increases reproducibity)
- **Home Manager**: home-directory management module; installs user programs, pkgs, and config files, sets env-variables, dotfiles, and any other arbitrary file
- **Modules**: to customize options, settings, and functionality in config
  - segregation of system and user level modules, encapsulated by role or function
- **Overlays**: custom modifications, extensions, and patches of Nixpkgs
- Single source of truth: repo serves as the reference point where all systems auto-pull from, and push to

Aspirational
- Declarative virtualization systems
- Scripting for initial hardware configuration (disko)
- Support for various WMs and desktop environments (KDE, XFCE, and Sway)
- Custom packages and services
- Secret management system
- Impermanent system; declaratively built on boot and connected to storage drives for data persistence

# Implementations
- **Installation**:
  1) Install NixOS with appropriate labelled partitions (boot, root, swap, home)
  2) First rebuild, with: flakes enabled and a proper hostname,
  3) Second rebuild, with `sudo nixos-rebuild boot --flake github:temhr/nixlab && sudo reboot`
- Updating systems imperatively:
  - **Flakes**: ` $ nix flake update --flake /home/temhr/nixlab`
  - **NixOS**: ` $ sudo nixos-rebuild switch --flake /home/temhr/nixlab`
  - **Cachix**: ` $ sudo cachix use [package_name]`

# Repository Layout
- **cachix**: prebuilt cached binaries to pull
- **home**: user level configurations (home manager) and files
  - **common**: user-agnostic settings and options
    - **core**: universal to all users
    - **optional**: user selection required
  - **files**: various user related files and scripts
  - **guest**: user-specfic preferences
  - **temhr**: user-specfic preferences
- **hosts**: system level configurations and files
  - **common**: host-agnostic programs, services, users, etc.
    - **core**: universal to all hosts
    - **optional**: host selection required
  - **files**: various host related scripts
  - **nixace**: host-specfic preferences - workstation
  - **nixbase**: host-specfic preferences - stationary
  - **nixser**: host-specfic preferences - server
  - **nixtop**: host-specfic preferences - laptop
- **lib**: templates and other nix-code
- **modules**: encapsulated nix expressions and customized applications
  - **home-manager**: user-relevant modules
  - **nixos**: system-relevant modules
- **overlays**: custom overrides and extensions
  - **default**: repository switching via flags (pkgs.unstable, pkgs.stable)
- **pkgs**: custom written packages
  - empty
- **scripts**: various shell scripts
-  flake.nix: entry point
-  flake.lock: version pinner
