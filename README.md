# Nix system configuration

My ad hoc initial Nix implementation for my Linux laptops, desktops, or homelab servers. A work-in-progress mostly adapted from [Misterio77's standard starter config](https://github.com/Misterio77/nix-starter-configs).

# Features
Contains
- **Flakes**: entrypoint; version-pins pkg dependencies in a lock file
- **Home Manager**: declarative configuration for user environment (packages and dotfiles)
- **Overlays**: extends and applies changes to package sets (nixpkgs)
- **Togglables**: allows for a combinatorial number of configuration options

Asperational
- Automatic daily update system
- Initial Hardware configuration scripting 
- Support for various WMs and desktop environments (KDE, XFCE, and Sway)
- Custom packages and services
- Flatpak support
- Secret management system

# Implementation
- **Installation**: protocol not established yet, helper shell scripts being developed
- Updating system:
  - **Flakes**: $ nix flake update --flake ./nixlab
  - **Home Manager**: $ home-manager switch --flake ./nixlab
  - **NixOS**: $ sudo nixos-rebuild switch

# Layout:
- **bin**: shell scripts for various functions
  - empty
- **home-manager**: stand alone from root and shared across hosts
- **hosts**: host-specific configuration files
  - common: shared and compartmentalized for machine/role/group
  - nixbase: multi-purpose stationary system
  - nixtop: multi-purpose mobile system
- **lib**: helper functions relating to config
  - empty
- **modules**: applications, services, user accounts, etc
  - home-manager: empty
  - nixOS: empty
- **overlays**: contains one overlay
  - default: makes the nixos-unstable repository available as pkgs.unstable
- **pkgs**: custom packages
  - empty
