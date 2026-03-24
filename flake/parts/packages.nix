{ ... }: {

  perSystem = { pkgs, ... }: {
    packages = import ../../pkgs pkgs;
    formatter = pkgs.alejandra;
  };

}
