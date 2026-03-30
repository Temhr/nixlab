{...}: {
  flake.homeModules = {
    # Common layers
    home--c-global = import ../../home/common/global;
    home--c-optional = import ../../home/common/optional;
    # Per-host user configs
    temhr-nixace = import ../../home/temhr/nixace.nix;
    temhr-nixsun = import ../../home/temhr/nixsun.nix;
    temhr-nixtop = import ../../home/temhr/nixtop.nix;
    temhr-nixvat = import ../../home/temhr/nixvat.nix;
    temhr-nixzen = import ../../home/temhr/nixzen.nix;
  };
}
