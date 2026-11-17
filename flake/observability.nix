{inputs, ...}: {
  # Surface the observability flake's modules as if they were native nixlab modules.
  # Names are unchanged, so existing `self.nixosModules.*` references keep working.
  flake.nixosModules = inputs.observability.nixosModules;
}
