# NixOS systems configuration

A work-in-progress Nix implementation for my Linux laptops, desktops, and homelab servers. Adapted from [Misterio77's standard starter config](https://github.com/Misterio77/nix-starter-configs).

# Features
Contains
- **Cachix**: cache of prebuilt nixpkgs binaries to speed up buildtime
- **Flakes**: entrypoint; version-pins nixpkg dependencies in a lock file
- **Home Manager**: declarative configuration for user environment (packages and dotfiles)
- **Modules**: configurations encapsulated by role or function
- **Overlays**: extends (applies changes to) package sets
  - **Togglables**: abstracts lengthy complexity from frontend config.nix file

Aspirational
- Declaraitive virtualization systems
- Initial hardware configuration scripting
- Support for various WMs and desktop environments (KDE, XFCE, and Sway)
- Custom packages and services
- Secret management system
- Impermanent system; declaratively built on boot and connected to storage drives for data persistence. 

# Implementation
- **Installation**: haven't established any personal methods or protocols yet
- Updating systems:
  - **Flakes**: ` $ nix flake update --flake /home/temhr/nixlab `
  - **Home Manager**: ` $ home-manager switch --flake /home/temhr/nixlab`
  - **NixOS**: ` $ sudo nixos-rebuild switch --flake /home/temhr/nixlab`
  - **Cachix**: ` $ sudo cachix use [package_name]`

# Layout:
-  **cachix**: prebuilt nixpkgs binaries pulled
- **home-manager**: user-environment config.nix file
- **hosts**: host-specific configuration files
  - **globals**: system agnostic configurations (applications, programs, services, user-account, etc.)
  - **nixace**: workstation config.nix file
  - **nixbase**: stationary config.nix file
  - **nixser**: server config.nix file
  - **nixtop**: laptop config.nix file
- **modules**: togglable configuration elements
  - **home-manager**: user-relevant modules
  - **nixos**: system-relevant modules
- **overlays**: contains one overlay
  - **default**: allows for nixos-unstable repository as pkgs.unstable
- **pkgs**: custom packages
  - empty
-  flake: the flake.nix (entry config) and flake.lock (version pinner) files
