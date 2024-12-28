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
    ];

}