# Nix sys configuration

My ad hoc initial Nix implementation for my Linux laptops, desktops, or homelab servers. A work-in-progress mostly adapted from [Misterio77's standard starter config](https://github.com/Misterio77/nix-starter-configs).

# Features
Contains
- Flakes: entrypoint to nix and
- Overlays: extends and applies changes to package sets (nixpkgs)

Asperational
- Togglable Modules: provides a combinatorial number of configuration options per system
- Home Manager: home directory organizational and dotfile management system
- Automatic daily updates
- Setup hardware configurations
- Support for various GUIs and desktop environments including  KDE, XFCE, and Sway
- Custom packages and services
- Flatpaks
- Secrets

# Implementation
- Installation: protocol not established et
- Updating system:
  - Flakes: $ nix flake update --flake ./nixlab
  - NixOS: $ sudo nixos-rebuild switch

# Repository structure:
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
