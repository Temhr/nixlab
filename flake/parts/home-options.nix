{lib, ...}: {
  options.flake.temhr-nixace = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = {};
    description = "Home Manager modules exported by this flake.";
  };
  options.flake.temhr-nixsun = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = {};
    description = "Home Manager modules exported by this flake.";
  };
  options.flake.temhr-nixtop = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = {};
    description = "Home Manager modules exported by this flake.";
  };
  options.flake.temhr-nixvat = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = {};
    description = "Home Manager modules exported by this flake.";
  };
  options.flake.temhr-nixzen = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = {};
    description = "Home Manager modules exported by this flake.";
  };
  options.flake.homeModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = {};
    description = "Home Manager modules exported by this flake.";
  };
}
