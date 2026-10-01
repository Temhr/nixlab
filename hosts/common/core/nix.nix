{...}: {
  flake.nixosModules.hosts--core--nix = {
    inputs,
    lib,
    ...
  }: {
    nix = let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in {
      settings = {
        # Enable flakes and new 'nix' command
        experimental-features = ["nix-command" "flakes"];
        # Opinionated: disable global registry
        flake-registry = "";
        # Make nix path match flake inputs
        nix-path = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

        ## Optimize storage (only for incoming/new files)
        auto-optimise-store = true;
      };
      # Opinionated: disable channels
      channel.enable = false;

      # Opinionated: make flake registry match flake inputs
      registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    };
  };
}
