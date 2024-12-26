# NixOS systems configuration

A work-in-progress Nix implementation for my Linux laptops, desktops, and homelab servers. Mostly adapted from [Misterio77's standard starter config](https://github.com/Misterio77/nix-starter-configs).

# Features
Contains
- **Flakes**: entrypoint; version-pins pkg dependencies in a lock file
- **Home Manager**: declarative configuration for user environment (packages and dotfiles)
- **Overlays**: extends and applies changes to package sets
- **Modules**: shared configuration files compartmentalized by role or function
  - **Togglables**: allows for a combinatorial amount of simple configuration options

Asperational
- Declaraitive virtualization systems
- Initial hardware configuration scripting
- Support for various WMs and desktop environments (KDE, XFCE, and Sway)
- Custom packages and services
- Flatpak support
- Secret management system

# Implementation
- **Installation**: haven't established a protocol yet, will develop helper shell scripts 
- Updating systems:
  - **Flakes**: ` $ nix flake update --flake ./nixlab `
  - **Home Manager**: ` $ home-manager switch --flake ./nixlab `
  - **NixOS**: ` $ sudo nixos-rebuild switch `

# Layout:
- **home-manager**: user-specific environment; unified across hosts
- **hosts**: host-relevant, system configuration files and modules 
  - **common**: shared modules (applications, services, user accounts, etc)
  - **nixbase**: system 1
  - **nixtop**: system 2
- **modules**: user/host agnostic modules (applications, services, etc)
  - home-manager: empty
  - **nixos**: gaming
- **overlays**: contains one overlay
  - **default**: allows for nixos-unstable repository as pkgs.unstable
- **pkgs**: custom packages
  - empty
