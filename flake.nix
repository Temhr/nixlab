{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the nixos-24.11 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    # NixOS official package source, using the nixos-unstable branch
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  # Outputs field: Defines what this flake provides (such as NixOS configurations, packages, etc.).
  outputs = inputs@{ self, nixpkgs, ... }: {
    nixosConfigurations = {

#      nixace = nixpkgs.lib.nixosSystem {
#        system = "x86_64-linux";
#        modules = [
#          ./configuration.nix
#        ];
#      };
#      nixbase = nixpkgs.lib.nixosSystem {
#        system = "x86_64-linux";
#        modules = [
#          ./configuration.nix
#        ];
#      };
#      nixser = nixpkgs.lib.nixosSystem {
#        system = "x86_64-linux";
#        modules = [
#          ./configuration.nix
#        ];
#      };
      nixtop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/nixtop/configuration.nix
          {
            _module.args = { inherit inputs; };
          }
        ];
      };

    };
  };
}
