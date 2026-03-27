{
  self,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs) lib;

  allOverlays = [
    self.overlays.unstable-packages
    self.overlays.stable-packages
    self.overlays.ollama-packages
    self.overlays.additions
    self.overlays.modifications
  ];

  commonModules = [
    inputs.sops-nix.nixosModules.sops
    self.nixosModules.home-manager-config
    {nixpkgs.overlays = allOverlays;}
  ];

  mkHost = {
    system ? "x86_64-linux",
    modules,
  }:
    lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs self;
        outputs = self;
        flakePath = self;
        # self' scoped to this system — available in any module that
        # declares it as an argument: { self', ... }
        self' =
          self.packages.${system}
          // {
            packages = self.packages.${system};
            devShells = self.devShells.${system};
            apps = self.apps.${system} or {};
          };
      };
      modules = commonModules ++ modules;
    };
in {
  flake.lib.mkHost = mkHost;

  flake.nixosModules.home-manager-config = {
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
}
