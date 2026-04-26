# WARN: this file will get overwritten by $ cachix use <name>
{...}: {
  flake.nixosModules.systm--cachix = {
    flakePath,
    lib,
    ...
  }: let
    folder = flakePath + /cachix;
    toImport = name: _: folder + ("/" + name);
    filterCaches = key: value: value == "regular" && lib.hasSuffix ".nix" key;
    imports =
      if builtins.pathExists folder
      then lib.mapAttrsToList toImport (lib.filterAttrs filterCaches (builtins.readDir folder))
      else [];
  in {
    inherit imports;

    # Default Nix cache settings
    nix.settings = {
      substituters = ["https://cache.nixos.org"];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };
  };
}
