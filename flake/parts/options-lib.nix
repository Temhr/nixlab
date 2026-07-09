{lib, ...}: {
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = {};
    description = "Shared library functions and metadata exported by this flake.";
  };
}
