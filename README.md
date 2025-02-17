A work-in-progress Nix implementation for my Linux laptops, desktops, and homelab servers. Adapted from [Misterio77's standard starter config](https://github.com/Misterio77/nix-starter-configs) with inspiration from [8bitbuddhism](https://code.8bitbuddhism.com/aires/nix-configuration) and many others.

- [Nix Ecosystem Terminology](#nix-ecosystem-terminology)
- [Nixlab Features](#nixlab-features)
- [Implementations](#implementations)
- [Repository Layout](#repository-layout)

# Nix Ecosystem Terminology
- Nix Language: a domain-specific, declarative, pure, functional, lazy-evaluated, dynamically typed, language
  - Nix values: data types that are immutable, can be whole **expressions** themselves, are only computed when needed, and type-error detected at evaluation
- Nix Expressions: **Nix lang** code (functions) that describes how to build packages or configure systems
  - Derivations: the backend build task; specifies all inputs, dependencies, and build steps of an **expression**
- Nix Packages Collection (Nixpkgs): a large repository of **Nix expressions**
- Nix Store: complex abstrations of immutable file system data (software packages, dependencies, etc.)
- Nix Package Manager: a command-line toolset which:
  1) evaluates **expressions** into **derivations**
  2) builds packages from **derivations** 
  3) manages the **Nix Store** (handles dependencies, ensures reproducibility), where packages are kept
- NixOS: Linux distro with a system configuration thats entirely built with Nix

# Nixlab Features
Contains
- **Cachix**: cache service of prebuilt binaries; speeds installs, avoids compilation 
- **Flakes**: a schema for writing, referencing, and sharing **Nix expressions**
  - consists of a filesystem tree with a flake.nix file in root directory; specifies:
    - metadata about the flake
    - inputs (**Nix expressions**, pkg repos, other flakes) which are taken as dependencies
    - outputs (pkg defs, dev-envs, NixOS configs, modules, etc.) which are given as **Nix values** usable by **Nix package manager**
  - updates **Nix package manager**'s CLI with the new/experimental commands
  - increases reproducibity by pinning version-controled dependencies via flake.lock file
- **Home Manager**: home-directory managment module; installs user programs, pkgs, and config files, sets env-variables, dotfiles, and any other arbitrary file.
- **Modules**: library of **Nix expressions** (structured nix files) encapsulated by role or function
  - Togglable, with complexity abstracted away from frontend host config.nix file
- **Overlays**: custom modifications and extensions of Nixpkgs and other pkg sets
- Single source of truth - systemd timer & service to invoke periodic pulls & builds of this repo 

Aspirational
- Declarative virtualization systems
- Scripting for initial hardware configuration (disko)
- Support for various WMs and desktop environments (KDE, XFCE, and Sway)
- Custom packages and services
- Secret management system
- Impermanent system; declaratively built on boot and connected to storage drives for data persistence
- Making possible use of nix related libraries (Snowfall)

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
- **bin**: various user files and shell scripts
- **cachix**: prebuilt nixpkgs binaries to pull
- **home-manager**: user-environment config.nix file
- **hosts**: host-specific configurations
  - **globals**: host-agnostic configs (applications, programs, services, user-account, etc.)
  - **nixace**: workstation config.nix file
  - **nixbase**: stationary config.nix file
  - **nixser**: server config.nix file
  - **nixtop**: laptop config.nix file
- **lib**: Unused nix-code dump
- **modules**: togglable configuration elements
  - **home-manager**: user-relevant preferences and extensions
  - **nixos**: system-relevant modules
- **overlays**: contains one overlay
  - **default**: allows for nixos-unstable repository as pkgs.unstable
- **pkgs**: custom packages
  - empty
-  flake.nix: entry point
-  flake.lock: version pinner
