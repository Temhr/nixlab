# Reference template for a new host file. Copy this into hosts/<name>.nix,
# fill in the hardware/host-config imports, then uncomment only the toggles
# this specific host needs. This file is NOT imported anywhere — it exists
# purely as the canonical menu so new options are added here once, not
# copied into every host by hand.
{self, ...}: {
  flake.nixosConfigurations.CHANGEME = self.lib.mkHost {
    name = "CHANGEME";
    modules = [
      # Hardware
      self.nixosModules.hardw--CHANGEME
      # Host config
      self.nixosModules.hosts--CHANGEME
      self.nixosModules.hosts--profl--base
      self.nixosModules.hosts--profl--desktop
      # Services
    ];
  };
  flake.nixosModules.hosts--CHANGEME = {
    #config,
    #pkgs,
    ...
  }: {
    ## DEVELOPMENT
    blender.enable = true; #3D Creation/Animation/Publishing System
    godot.enable = true; #Free and Open Source 2D and 3D game engine
    vscodium.enable = true; #VS Code without MS branding/telemetry/licensing
    ## EDUCATION
    anki.enable = true; #Spaced repetition flashcard program
    ## GAMING PACKAGES
    steam.enable = true; #Video game digital distribution service and storefront from Valve
    ## PRODUCTIVITY
    calibre.enable = true; #Comprehensive e-book software
    libreoffice.enable = true; #Comprehensive, professional-quality productivity suite
    logseq.enable = true; #Privacy-first, open-source platform for knowledge management and collaboration
    ## MEDIA PACKAGES
    obs.enable = true; #Free and open source software for video recording and live streaming
    spotify.enable = true; #Play music from the Spotify music service
    vlc.enable = true; #Cross-platform media player and streaming server
    ## VIRTUALIZATIONS
    bottles.enable = true; #Easy-to-use wineprefix manager
    distrobox.enable = true; #Wrapper around podman or docker to create and start containers
    incus.enable = true; #Powerful system container and virtual machine manager
    podman.enable = true; #A program for managing pods, containers and container images
    quickemu.enable = true; #Quickly create and run optimised Windows, macOS and Linux virtual machines
    virt-manager.enable = true; #Desktop user interface for managing virtual machines
    wine.enable = true; #Open Source implementation of the Windows API on top of X, OpenGL, and Unix
    virtualisation.waydroid.enable = true; #requires "$sudo waydroid init" with "-s GAPPS -f" flag option
  };
}
