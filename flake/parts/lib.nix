# flake/parts/lib.nix
{
  self,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs) lib;

  hostsMeta = {
    nixace = {
      system = "x86_64-linux";
      gateway = "192.168.0.1";
      prefixLength = 24;
      nameservers = ["1.1.1.1" "9.9.9.9"];
      interfaces = [
        {
          name = "enp0s31f6";
          address = "192.168.0.200";
          type = "ethernet";
        }
        {
          name = "wlp3s0";
          address = "192.168.0.200";
          type = "wifi";
        }
      ];
    };
    nixsun = {
      system = "x86_64-linux";
      gateway = "192.168.0.1";
      prefixLength = 24;
      nameservers = ["1.1.1.1" "9.9.9.9"];
      interfaces = [
        {
          name = "enp0s25";
          address = "192.168.0.203";
          type = "ethernet";
        }
        {
          name = "wlo1";
          address = "192.168.0.203";
          type = "wifi";
        }
      ];
    };
    nixtop = {
      system = "x86_64-linux";
      gateway = "192.168.0.1";
      prefixLength = 24;
      nameservers = ["1.1.1.1" "9.9.9.9"];
      interfaces = [
        {
          name = "enp0s25";
          address = "192.168.0.202";
          type = "ethernet";
        }
        {
          name = "wlp61s0";
          address = "192.168.0.202";
          type = "wifi";
        }
      ];
    };
    nixvat = {
      system = "x86_64-linux";
      gateway = "192.168.0.1";
      prefixLength = 24;
      nameservers = ["1.1.1.1" "9.9.9.9"];
      interfaces = [
        {
          name = "enp0s25";
          address = "192.168.0.201";
          type = "ethernet";
        }
        {
          name = "wlo1";
          address = "192.168.0.201";
          type = "wifi";
        }
      ];
    };
    nixzen = {
      system = "x86_64-linux";
      gateway = "192.168.0.1";
      prefixLength = 24;
      nameservers = ["1.1.1.1" "9.9.9.9"];
      interfaces = [
        {
          name = "enp0s25";
          address = "192.168.0.204";
          type = "ethernet";
        }
        {
          name = "wlp61s0";
          address = "192.168.0.204";
          type = "wifi";
        }
      ];
    };
  };

  allOverlays = [
    self.overlays.unstable-packages
    self.overlays.stable-packages
    self.overlays.additions
    self.overlays.modifications
  ];

  commonModules = [
    inputs.sops-nix.nixosModules.sops
    self.nixosModules.systm--home-manager-config
    {nixpkgs.overlays = allOverlays;}
  ];

  mkHost = {
    name,
    modules,
  }: let
    meta = hostsMeta.${name};
  in
    assert lib.assertMsg
    (builtins.hasAttr name hostsMeta)
    "mkHost: no hostsMeta entry found for '${name}' — add it to the hostsMeta attrset in flake/parts/lib.nix";
      lib.nixosSystem {
        system = meta.system;
        specialArgs = {
          inherit inputs self;
          outputs = self;
          flakePath = self;
          allHosts = hostsMeta;
          hostMeta = meta;
          self' =
            self.packages.${meta.system}
            // {
              packages = self.packages.${meta.system};
              devShells = self.devShells.${meta.system};
              apps = self.apps.${meta.system} or {};
            };
        };
        modules =
          commonModules
          ++ modules
          ++ [
            {networking.hostName = name;}
          ];
      };
in {
  flake.lib = {inherit mkHost hostsMeta;};
}
