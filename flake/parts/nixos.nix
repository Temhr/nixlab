{
  inputs,
  self,
  ...
}: let
  inherit (inputs.nixpkgs) lib;
  sys = "x86_64-linux";

  allOverlays = [
    self.overlays.unstable-packages
    self.overlays.stable-packages
    self.overlays.ollama-packages
    self.overlays.additions
    self.overlays.modifications
  ];

  # Injected into every host. Host files never declare these.
  commonModules = [
    inputs.sops-nix.nixosModules.sops
    self.nixosModules.home-manager-config
    {nixpkgs.overlays = allOverlays;}
  ];

  mkHost = {
    system ? sys,
    modules,
  }:
    lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs self;
        outputs = self; # backwards compat
        flakePath = self; # used by nixace sops
      };
      modules = commonModules ++ modules;
    };
in {
  # ───────────────────────────────────────────────────────────
  # MODULE REGISTRY — stable names, resilient wiring
  # ───────────────────────────────────────────────────────────
  flake.nixosModules = {
    # Home-manager shared config (replaces inline attrset)
    home-manager-config = {
      imports = [inputs.home-manager.nixosModules.home-manager];
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit inputs self;
          outputs = self;
          flakePath = self;
        };
      };
    };

    # Module — owns its own secrets path
    secrets-bookstack = import ../../hosts/common/optional/secrets-bookstack.nix;
    secrets-grafana = import ../../hosts/common/optional/secrets-grafana.nix;

    # Hardware — common layers
    hw-common-global = import ../../hardware/common/global;
    hw-common-optional = import ../../hardware/common/optional;

    # Hardware — per-device
    hw-zb17g4-p5 = import ../../hardware/zb17g4-p5.nix; # nixace
    hw-zb17g1-k4 = import ../../hardware/zb17g1-k4.nix; # nixsun
    hw-zb17g2-k5 = import ../../hardware/zb17g2-k5.nix; # nixtop
    hw-zb17g1-k3 = import ../../hardware/zb17g1-k3.nix; # nixvat
    hw-zb15g2-k1 = import ../../hardware/zb15g2-k1.nix; # nixzen

    # System — shared layers
    hosts-global = import ../../hosts/common/global;
    hosts-optional = import ../../hosts/common/optional;
    cachix = import ../../cachix.nix;

    # System — nixzen-only optional
    auto-backup-phone-media =
      import ../../hosts/common/optional/auto-backup-phone-media.nix;

    # System — per-host (hostname + imports injected here)
    nixace = {
      networking.hostName = "nixace";
      imports = [(import ../../hosts/nixace.nix)];
    };
    nixsun = {
      networking.hostName = "nixsun";
      imports = [(import ../../hosts/nixsun.nix)];
    };
    nixtop = {
      networking.hostName = "nixtop";
      imports = [(import ../../hosts/nixtop.nix)];
    };
    nixvat = {
      networking.hostName = "nixvat";
      imports = [
        (import ../../hosts/nixvat.nix)
        "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
      ];
    };
    nixzen = {
      networking.hostName = "nixzen";
      imports = [
        (import ../../hosts/nixzen.nix)
        self.nixosModules.auto-backup-phone-media
      ];
    };
  };

  # ───────────────────────────────────────────────────────────
  # HOST CONFIGURATIONS
  # ───────────────────────────────────────────────────────────
  flake.nixosConfigurations = {
    nixace = mkHost {
      modules = [
        self.nixosModules.hw-common-global
        self.nixosModules.hw-common-optional
        self.nixosModules.hw-zb17g4-p5
        self.nixosModules.hosts-global
        self.nixosModules.hosts-optional
        self.nixosModules.cachix
        self.nixosModules.nixace
        self.nixosModules.bookstack-nixlab
        self.nixosModules.secrets-bookstack
        self.nixosModules.comfyui-p5000
        self.nixosModules.comfyui-extensions
        self.nixosModules.comfyui-models
        self.nixosModules.grafana-nixlab
        self.nixosModules.secrets-grafana
        self.nixosModules.homepage-nixlab
        self.nixosModules.loki-nixlab
        self.nixosModules.ollama-cpu
        self.nixosModules.ollama-p5000
        self.nixosModules.prometheus-nixlab
        self.nixosModules.glance-nixlab
        self.nixosModules.gotosocial-nixlab
        self.nixosModules.home-assistant-nixlab
        self.nixosModules.node-red-nixlab
        self.nixosModules.syncthing-nixlab
        self.nixosModules.waydroid-nixlab
        self.nixosModules.wiki-js-custom
        self.nixosModules.zola-custom
      ];
    };
    nixsun = mkHost {
      modules = [
        self.nixosModules.hw-common-global
        self.nixosModules.hw-common-optional
        self.nixosModules.hw-zb17g1-k4
        self.nixosModules.hosts-global
        self.nixosModules.hosts-optional
        self.nixosModules.cachix
        self.nixosModules.nixsun
        self.nixosModules.bookstack-nixlab
        self.nixosModules.secrets-bookstack
        self.nixosModules.comfyui-p5000
        self.nixosModules.comfyui-extensions
        self.nixosModules.comfyui-models
        self.nixosModules.grafana-nixlab
        self.nixosModules.secrets-grafana
        self.nixosModules.homepage-nixlab
        self.nixosModules.loki-nixlab
        self.nixosModules.ollama-cpu
        self.nixosModules.ollama-p5000
        self.nixosModules.prometheus-nixlab
        self.nixosModules.glance-nixlab
        self.nixosModules.gotosocial-nixlab
        self.nixosModules.home-assistant-nixlab
        self.nixosModules.node-red-nixlab
        self.nixosModules.syncthing-nixlab
        self.nixosModules.waydroid-nixlab
        self.nixosModules.wiki-js-custom
        self.nixosModules.zola-custom
      ];
    };
    nixtop = mkHost {
      modules = [
        self.nixosModules.hw-common-global
        self.nixosModules.hw-common-optional
        self.nixosModules.hw-zb17g2-k5
        self.nixosModules.hosts-global
        self.nixosModules.hosts-optional
        self.nixosModules.cachix
        self.nixosModules.nixtop
        self.nixosModules.bookstack-nixlab
        self.nixosModules.secrets-bookstack
        self.nixosModules.comfyui-p5000
        self.nixosModules.comfyui-extensions
        self.nixosModules.comfyui-models
        self.nixosModules.grafana-nixlab
        self.nixosModules.secrets-grafana
        self.nixosModules.homepage-nixlab
        self.nixosModules.loki-nixlab
        self.nixosModules.ollama-cpu
        self.nixosModules.ollama-p5000
        self.nixosModules.prometheus-nixlab
        self.nixosModules.glance-nixlab
        self.nixosModules.gotosocial-nixlab
        self.nixosModules.home-assistant-nixlab
        self.nixosModules.node-red-nixlab
        self.nixosModules.syncthing-nixlab
        self.nixosModules.waydroid-nixlab
        self.nixosModules.wiki-js-custom
        self.nixosModules.zola-custom
      ];
    };
    nixvat = mkHost {
      modules = [
        self.nixosModules.hw-common-global
        self.nixosModules.hw-common-optional
        self.nixosModules.hw-zb17g1-k3
        self.nixosModules.hosts-global
        self.nixosModules.hosts-optional
        self.nixosModules.cachix
        self.nixosModules.nixvat
        self.nixosModules.bookstack-nixlab
        self.nixosModules.secrets-bookstack
        self.nixosModules.comfyui-p5000
        self.nixosModules.comfyui-extensions
        self.nixosModules.comfyui-models
        self.nixosModules.grafana-nixlab
        self.nixosModules.secrets-grafana
        self.nixosModules.homepage-nixlab
        self.nixosModules.loki-nixlab
        self.nixosModules.ollama-cpu
        self.nixosModules.ollama-p5000
        self.nixosModules.prometheus-nixlab
        self.nixosModules.glance-nixlab
        self.nixosModules.gotosocial-nixlab
        self.nixosModules.home-assistant-nixlab
        self.nixosModules.node-red-nixlab
        self.nixosModules.syncthing-nixlab
        self.nixosModules.waydroid-nixlab
        self.nixosModules.wiki-js-custom
        self.nixosModules.zola-custom
      ];
    };
    nixzen = mkHost {
      modules = [
        self.nixosModules.hw-common-global
        self.nixosModules.hw-common-optional
        self.nixosModules.hw-zb15g2-k1
        self.nixosModules.hosts-global
        self.nixosModules.hosts-optional
        self.nixosModules.cachix
        self.nixosModules.nixzen
        self.nixosModules.bookstack-nixlab
        self.nixosModules.secrets-bookstack
        self.nixosModules.comfyui-p5000
        self.nixosModules.comfyui-extensions
        self.nixosModules.comfyui-models
        self.nixosModules.grafana-nixlab
        self.nixosModules.secrets-grafana
        self.nixosModules.homepage-nixlab
        self.nixosModules.loki-nixlab
        self.nixosModules.ollama-cpu
        self.nixosModules.ollama-p5000
        self.nixosModules.prometheus-nixlab
        self.nixosModules.glance-nixlab
        self.nixosModules.gotosocial-nixlab
        self.nixosModules.home-assistant-nixlab
        self.nixosModules.node-red-nixlab
        self.nixosModules.syncthing-nixlab
        self.nixosModules.waydroid-nixlab
        self.nixosModules.wiki-js-custom
        self.nixosModules.zola-custom
      ];
    };
  };
}
