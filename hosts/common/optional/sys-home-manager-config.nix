# Shared Home Manager NixOS module.
{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.systm--home-manager-config = {
    imports = [inputs.home-manager.nixosModules.home-manager];
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit inputs self;
        outputs = self;
        flakePath = self;
        allHosts = self.lib.hostsMeta;
      };
    };
  };
}
