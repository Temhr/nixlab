{self, ...}: {
  flake.homeModules.home--c-optional = {...}: {
    imports = [
      ./_optional
    ];
  };
}
