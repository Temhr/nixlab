{...}: {
  flake.nixosModules.hosts--autom--nix-gc = {...}: {
    ## Garbage collection to maintain low disk usage
    nix.gc = {
      automatic = true;
      dates = "*-*-* 02:00:00";
      options = "--delete-older-than 5d";
    };
  };
}
