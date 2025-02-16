A work-in-progress, Nix implementation for my Linux laptops, desktops, and homelab servers. Adapted from [Misterio77's standard starter config](https://github.com/Misterio77/nix-starter-configs) with inspiration from [8bitbuddhism](https://code.8bitbuddhism.com/aires/nix-configuration) and many others.

# Basic Nix Ecosystem Terminology
- Nix Language: a domain-specific, declarative, pure, functional, lazy-evaluated, dynamically typed, language
- Nix Expressions: **Nix lang** code which describes how to build packages or configure systems
  - Derivations: the backend build task; specifies all inputs, dependencies, and build steps of an **expression**
- Nix Packages Collection (Nixpkgs): a large repository of **Nix expressions**
- Nix Store: complex abstrations of immutable file system data (software packages, dependencies, etc.)
- Nix Package Manager: a command-line toolset which:
  1) evaluates **expressions** into **derivations**
  2) builds packages from **derivations** 
  3) manages the **Nix Store** where packages are kept (handles dependencies, ensures reproducibility)
- NixOS: Linux distro with a system configuration thats entirely built with Nix

# Features
Contains
- **Cachix**: cache of prebuilt nixpkgs binaries to speed up buildtime
- **Flakes**: schema for writing, referencing, and sharing Nix expressions (to build derivations, run programs, etc.)
  - takes inputs (Nix expressions, pkg repos, other flakes) to produce outputs (pkg defs, dev-envs, NixOS configs) which become usable by Nix package manager
  - increases reproducibity by pinning version-controled dependencies via lock file
- **Home Manager**: declarative config module, specifically for user environment (packages and dotfiles)
- **Modules**: configurations encapsulated by role or function
- **Overlays**: extends, applies changes to, nixpkgs (nix package sets)
- Togglables: abstracts complexity away from frontend config.nix file
- Single source of truth - systemd timer & service invokes shell script to periodcally pull and build from this repo 

Aspirational
- Declarative virtualization systems
- Scripting for initial hardware configuration (disko)
- Support for various WMs and desktop environments (KDE, XFCE, and Sway)
- Custom packages and services
- Secret management system
- Impermanent system; declaratively built on boot and connected to storage drives for data persistence
- Making possible use of nix related libraries (Snowfall)

# Implementation
- **Installation**:
  1) Install NixOS with appropriate labelled partitions (boot, root, swap, home)
  2) First rebuild, with: flakes enabled and a proper hostname,
  3) Second rebuild, with `sudo nixos-rebuild boot --flake github:temhr/nixlab && sudo reboot`
- Updating systems imperatively:
  - **Flakes**: ` $ nix flake update --flake /home/temhr/nixlab`
  - **NixOS**: ` $ sudo nixos-rebuild switch --flake /home/temhr/nixlab`
  - **Cachix**: ` $ sudo cachix use [package_name]`

# Layout:
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
