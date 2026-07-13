{lib, ...}: let
  hostModule = {config, ...}: {
    options = {
      address = lib.mkOption {
        type = lib.types.str;
        description = "Primary IPv4 address for this host.";
      };
      ethIface = lib.mkOption {
        type = lib.types.str;
        description = "Ethernet interface name (e.g. from `ip link`).";
      };
      wifiIface = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Wifi interface name; empty string if the host has no wifi.";
      };
      system = lib.mkOption {
        type = lib.types.str;
        default = "x86_64-linux";
      };
      gateway = lib.mkOption {
        type = lib.types.str;
        default = "10.0.0.1";
      };
      prefixLength = lib.mkOption {
        type = lib.types.ints.between 0 32;
        default = 24;
      };
      nameservers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["9.9.9.9" "1.1.1.1"];
      };
      hostId = lib.mkOption {
        # 8 hex chars, as produced by `head -c 8 /etc/machine-id` — genuinely
        # catches a mistyped/truncated hostId now, which `raw` never could.
        type = lib.types.nullOr (lib.types.strMatching "[0-9a-f]{8}");
        default = null;
        description = "8-hex-char host ID for networking.hostId.";
      };
      nixpkgsInput = lib.mkOption {
        # Deliberately `str`, not `enum [...]`: builders/hosts.nix already
        # asserts this string names a real flake input at eval time
        # (`assert hasAttr meta.nixpkgsInput inputs`). Hardcoding a fixed
        # list here would just be a second, disconnected place to keep in
        # sync with flake.nix's `inputs` — the exact kind of duplication
        # this refactor is meant to remove, not reintroduce.
        type = lib.types.str;
        default = "nixpkgs";
        description = "Which flake input to build this host's pkgs from.";
      };
      homeUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Usernames (from usersMeta) that get a home-manager profile on this host.";
      };
      systemUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Usernames (from usersMeta) that get a NixOS account on this host.";
      };
      primaryUser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Which systemUser is nixlab.mainUser on this host.";
      };
      interfaces = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {type = lib.types.str;};
            address = lib.mkOption {type = lib.types.str;};
            type = lib.mkOption {type = lib.types.enum ["ethernet" "wifi"];};
          };
        });
        default = [];
        internal = true; # derived below — not meant to be set by callers
        description = "Derived automatically from ethIface/wifiIface/address.";
      };
    };

    config.interfaces =
      [
        {
          name = config.ethIface;
          inherit (config) address;
          type = "ethernet";
        }
      ]
      ++ lib.optionals (config.wifiIface != "") [
        {
          name = config.wifiIface;
          inherit (config) address;
          type = "wifi";
        }
      ];
  };
in {
  flake.lib.mkHostMeta = attrs:
    builtins.removeAttrs
    (lib.evalModules {modules = [hostModule {config = attrs;}];}).config
    ["_module"];
}
