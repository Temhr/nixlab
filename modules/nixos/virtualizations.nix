{ config, lib, pkgs, ... }: {

    options = {
        bottles = {
            enable = lib.mkEnableOption {
              description = "Enables Bottles";
              default = false;
            };
        };
        distrobox = {
            enable = lib.mkEnableOption {
              description = "Enables Distrobox";
              default = false;
            };
        };
        incus = {
            enable = lib.mkEnableOption {
              description = "Enables Incus";
              default = false;
            };
        };
        podman = {
            enable = lib.mkEnableOption {
              description = "Enables Podman";
              default = false;
            };
        };
        quickemu = {
            enable = lib.mkEnableOption {
              description = "Enables Quickemu";
              default = false;
            };
        };
        virt-manager = {
            enable = lib.mkEnableOption {
              description = "Enables Virt-Manager";
              default = false;
            };
        };
        wine = {
            enable = lib.mkEnableOption {
              description = "Enables Wine";
              default = false;
            };
        };
        home-assistant = {
            enable = lib.mkEnableOption {
              description = "Enables Home-Assistant";
              default = false;
            };
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.bottles.enable {
          environment.systemPackages = with pkgs; [ bottles ];  #Easy-to-use wineprefix manager
        })
        (lib.mkIf config.distrobox.enable {
          environment.systemPackages = with pkgs; [ distrobox ];  #Wrapper around podman or docker to create and start containers
        })
        (lib.mkIf config.incus.enable {

          # Enable Incus
          virtualisation.incus = {
            enable = true;
            ui.enable = true;  # Optional web UI
          };

          # Add your user to incus-admin group
          users.users."temhr".extraGroups = [ "incus-admin" ];

          # Enable IP forwarding for Incus
          boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

          # Network configuration for Incus
          networking = {
            # Enable nftables (required for Incus)
            nftables.enable = true;

            firewall = {
              enable = true;
              # Allow Home Assistant port
              allowedTCPPorts = [ 8123 ];

              # Trust Incus bridge interface
              trustedInterfaces = [ "incusbr0" ];
            };
          };

          # Required kernel modules
          boot.kernelModules = [ "veth" "xt_comment" ];
        })
        (lib.mkIf config.podman.enable {
          environment.systemPackages = with pkgs; [ podman ];  #A program for managing pods, containers and container images
        })
        (lib.mkIf config.quickemu.enable {
          environment.systemPackages = with pkgs; [ quickemu ];  #Quickly create and run optimised Windows, macOS and Linux virtual machines
        })
        (lib.mkIf config.virt-manager.enable {
          programs.virt-manager.enable = true;  #Desktop user interface for managing virtual machines
          virtualisation.libvirtd.enable = true;
          #Allows libvirtd to take advantage of OVMF when creating new QEMU VMs with UEFI boot
          virtualisation.libvirtd.qemu.ovmf.enable = true; #For UEFI boot of Home Assistant OS guest image
          virtualisation.spiceUSBRedirection.enable = true;
          users.users."temhr".extraGroups = ["libvirtd"];
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
        (lib.mkIf config.home-assistant.enable {
          #environment.systemPackages = [ pkgs.home-assistant ];  #Quickly create and run optimised Windows, macOS and Linux virtual machines
        })
    ];

}
