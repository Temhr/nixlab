{
  inputs,
  self,
  ...
}: let
  inherit (inputs.nixpkgs) lib;

  defaultSystem = "x86_64-linux";

  # NOTE: self.overlays.* replaces outputs.overlays.*
  allOverlays = [
    self.overlays.unstable-packages
    self.overlays.stable-packages
    self.overlays.ollama-packages
    self.overlays.additions
    self.overlays.modifications
  ];

  commonModules = [
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        sharedModules = [
        ];
      };
    }
  ];

  hosts = {
    nixace = {};
    nixsun = {};
    nixtop = {};
    nixvat = {
      modules = [
        "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
      ];
    };
    nixzen = {};
  };

  mkNixosSystem = hostname: {
    system ? defaultSystem,
    modules ? [],
    ...
  }: let
    hostConfigPath = ../../hosts/${hostname}.nix;
    errorMsg = ''
      Host configuration file not found: ${toString hostConfigPath}
      Please create hosts/${hostname}.nix
    '';
  in
    assert builtins.pathExists hostConfigPath || throw errorMsg;
      lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs hostname;
          outputs = self; # keep backwards compat for any host files
          flakePath = self; # paths from flake/root
        };
        modules =
          commonModules
          ++ modules
          ++ [
            {nixpkgs.overlays = allOverlays;}
            {networking.hostName = hostname;}
            hostConfigPath
          ];
      };
in {
  flake.nixosConfigurations = lib.mapAttrs mkNixosSystem hosts;
}
