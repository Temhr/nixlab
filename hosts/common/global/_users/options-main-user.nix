{lib, ...}: {
  options.nixlab.mainUser = lib.mkOption {
    type = lib.types.str;
    description = "The primary human user of this machine";
  };
}
