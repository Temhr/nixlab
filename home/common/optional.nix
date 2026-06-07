{self, ...}: {
  flake.homeModules.home--c-opt = {...}: {
    imports = [
      ./_optional
    ];
  };
}
