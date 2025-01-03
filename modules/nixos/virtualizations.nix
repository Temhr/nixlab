{ config, lib, pkgs, ... }: {

    options = {
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
    };

    config = lib.mkMerge [
        (lib.mkIf config.distrobox.enable {
          environment.systemPackages = [ pkgs.distrobox ];  #Wrapper around podman or docker to create and start containers
        })
        (lib.mkIf config.incus.enable {
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
          virtualisation.libvirtd.qemuOvmf = true; #For UEFI boot of Home Assistant OS guest image
          virtualisation.spiceUSBRedirection.enable = true;
        })
    ];

}
