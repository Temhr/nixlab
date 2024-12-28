# NixOS systems configuration

A work-in-progress Nix implementation for my Linux laptops, desktops, and homelab servers. Mostly adapted from [Misterio77's standard starter config](https://github.com/Misterio77/nix-starter-configs).

# Features
Contains
- **Flakes**: entrypoint; version-pins pkg dependencies in a lock file
- **Home Manager**: declarative configuration for user environment (packages and dotfiles)
- **Overlays**: extends (applys changes) to package sets
- **Modules**: shared configuration files, compartmentalized by role or function
  - **Togglable**: abstracts complexity from frontend configuration file

Asperational
- Declaraitive virtualization systems
- Initial hardware configuration scripting
- Support for various WMs and desktop environments (KDE, XFCE, and Sway)
- Custom packages and services
- Flatpak support
- Secret management system

# Implementation
- **Installation**: haven't established any personal methods or protocols yet
- Updating systems:
  - **Flakes**: ` $ nix flake update --flake ./nixlab `
  - **Home Manager**: ` $ home-manager switch --flake ./nixlab `
  - **NixOS**: ` $ sudo nixos-rebuild switch `

# Layout:
- **home-manager**: unified user environment across hosts
- **hosts**: host-relevant, system configuration files
  - **globals**: system agnostic (shared) applications, services, user accounts, etc
  - **nixbase**: system 1 config
  - **nixtop**: system 2 config
- **modules**: togglable user/host applications, services, etc
  - **home-manager**: user-specific modules
  - **nixos**: system-specific modules
- **overlays**: contains one overlay
  - **default**: allows for nixos-unstable repository as pkgs.unstable
- **pkgs**: custom packages
  - empty
