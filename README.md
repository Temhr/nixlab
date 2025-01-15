# NixOS systems configuration

A work-in-progress Nix implementation for my Linux laptops, desktops, and homelab servers. Adapted from [Misterio77's standard starter config](https://github.com/Misterio77/nix-starter-configs) with inspiration from [8bitbuddhism](https://code.8bitbuddhism.com/aires/nix-configuration)

# Features
Contains
- **Cachix**: cache of prebuilt nixpkgs binaries to speed up buildtime
- **Flakes**: version-pins nixpkg dependencies in a lock file
- **Home Manager**: declarative configuration for user environment (packages and dotfiles)
- **Modules**: configurations encapsulated by role or function
- **Overlays**: extends, applies changes to, nixpkgs (nix package sets)
- Togglables: abstracts complexity away from frontend config.nix file
- Single source of truth - systemd timer & service invokes shell script to periodcally pull this git repo 

Aspirational
- Declaraitive virtualization systems
- Scripting for initial hardware configuration
- Support for various WMs and desktop environments (KDE, XFCE, and Sway)
- Custom packages and services
- Secret management system
- Impermanent system; declaratively built on boot and connected to storage drives for data persistence
- Making possible use of nix related libraries (Snowfall)

# Implementation
- **Installation**:
  - 1) Install NixOS,
    2) Rebuild with: flakes, a proper hostname, and an autoUpgrade.service from this repo,
    3) Wait for autoUpgrade.service to rebuild from this repo (with hostname's configuration)   
- Updating systems:
  - **Flakes**: ` $ nix flake update --flake /home/temhr/nixlab `
  - **Home Manager**: ` $ home-manager switch --flake /home/temhr/nixlab`
  - **NixOS**: ` $ sudo nixos-rebuild switch --flake /home/temhr/nixlab`
  - **Cachix**: ` $ sudo cachix use [package_name]`

# Layout:
- **bin**: shell scripts for various functions
- **cachix**: prebuilt nixpkgs binaries to pull
- **home-manager**: user-environment config.nix file
- **hosts**: host-specific configuration files
  - **globals**: system agnostic configurations (applications, programs, services, user-account, etc.)
  - **nixace**: workstation config.nix file
  - **nixbase**: stationary config.nix file
  - **nixser**: server config.nix file
  - **nixtop**: laptop config.nix file
- **lib**: Unused nix code 
- **modules**: togglable configuration elements
  - **home-manager**: user-relevant modules
  - **nixos**: system-relevant modules
- **overlays**: contains one overlay
  - **default**: allows for nixos-unstable repository as pkgs.unstable
- **pkgs**: custom packages
  - empty
-  flake: the flake.nix (entry point of config) and flake.lock (version pinner) files.
