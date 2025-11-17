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
        waydroid = {
            enable = lib.mkEnableOption {
              description = "Enables waydroid";
              default = false;
            };
        };
        wine = {
            enable = lib.mkEnableOption {
              description = "Enables Wine";
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
            nftables.enable = true;
            firewall = {
              enable = true;
              # Allow port range
              allowedTCPPortRanges = [
                { from = 8123; to = 8123; }
                { from = 1880; to = 1880; }
                { from = 2665; to = 2665; }
                # Or a wider range if needed
                # { from = 8000; to = 9000; }
              ];
              trustedInterfaces = [ "incusbr0" ];
            };
            nat = {
              enable = true;
              internalInterfaces = ["incusbr0"];
              externalInterface = "wlp3s0";
              forwardPorts = [
                { destination = "10.24.51.164:8123"; proto = "tcp"; sourcePort = 8123; }
                { destination = "10.24.51.164:1880"; proto = "tcp"; sourcePort = 1880; }
                { destination = "10.24.51.164:2665"; proto = "tcp"; sourcePort = 2665; }
              ];
            };
          };

          # Required kernel modules
          boot.kernelModules = [ "veth" "xt_comment" ];
        })
        (lib.mkIf config.podman.enable {
          environment.systemPackages = with pkgs; [ podman ];  #A program for managing pods, containers and container images
        })
        (lib.mkIf config.quickemu.enable {
          environment.systemPackages = with pkgs; [ quickemu quickgui ];  #Quickly create and run optimised Windows, macOS and Linux virtual machines

        })
        (lib.mkIf config.virt-manager.enable {
          programs.virt-manager.enable = true;  #Desktop user interface for managing virtual machines
          virtualisation.libvirtd.enable = true;
          #Allows libvirtd to take advantage of OVMF when creating new QEMU VMs with UEFI boot
          virtualisation.libvirtd.qemu.ovmf.enable = true; #For UEFI boot of Home Assistant OS guest image
          virtualisation.spiceUSBRedirection.enable = true;
          users.users."temhr".extraGroups = ["libvirtd"];
        })
        (lib.mkIf config.waydroid.enable {
          #environment.systemPackages = [ pkgs.home-assistant ];  #Quickly create and run optimised Windows, macOS and Linux virtual machines
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
