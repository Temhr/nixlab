{ config, lib, pkgs, ... }: {

    options = {
        bottles = {
            enable = lib.mkEnableOption "enables Bottles";
        };
        distrobox = {
            enable = lib.mkEnableOption "enables Distrobox";
        };
        incus = {
            enable = lib.mkEnableOption "enables Incus";
        };
        podman = {
            enable = lib.mkEnableOption "enables Podman";
        };
        quickemu = {
            enable = lib.mkEnableOption "enables Quickemu";
        };
        virt-manager = {
            enable = lib.mkEnableOption "enables Virt-Manager";
        };
        wine = {
            enable = lib.mkEnableOption "enables Wine";
        };
        home-assistant = {
            enable = lib.mkEnableOption "enables Home-Assistant";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.bottles.enable {
          environment.systemPackages = [ pkgs.bottles ];  #Easy-to-use wineprefix manager
        })
        (lib.mkIf config.distrobox.enable {
          environment.systemPackages = [ pkgs.distrobox ];  #Wrapper around podman or docker to create and start containers
        })
        (lib.mkIf config.incus.enable {
          virtualisation.incus.enable = true;
          networking.nftables.enable = true;
          environment.systemPackages = [ pkgs.incus ];  #Powerful system container and virtual machine manager
        })
        (lib.mkIf config.podman.enable {
          environment.systemPackages = [ pkgs.podman ];  #A program for managing pods, containers and container images
        })
        (lib.mkIf config.quickemu.enable {
          environment.systemPackages = [ pkgs.quickemu ];  #Quickly create and run optimised Windows, macOS and Linux virtual machines
        })
        (lib.mkIf config.virt-manager.enable {
          programs.virt-manager.enable = true;  #Desktop user interface for managing virtual machines
          virtualisation.libvirtd.enable = true;
          #Allows libvirtd to take advantage of OVMF when creating new QEMU VMs with UEFI boot
          virtualisation.libvirtd.qemu.ovmf.enable = true; #For UEFI boot of Home Assistant OS guest image
          virtualisation.spiceUSBRedirection.enable = true;
        })
        (lib.mkIf config.wine.enable {  #Open Source implementation of the Windows API on top of X, OpenGL, and Unix
          environment.systemPackages = with pkgs; [
            wineWowPackages.stable #support both 32-bit and 64-bit applications
            wine  #support 42-bit only
            (wine.override { wineBuild = "wine64"; })  #support 64-bit only
            wine64   #support 64-bit only
            wineWowPackages.staging  #wine-staging (version with experimental features)
            winetricks  #winetricks (all versions)
            wineWowPackages.waylandFull  #native wayland support (unstable)
          ];
        })
    ];

}
