{ outputs, ... }: {
  nixpkgs = {
    # You can add overlays here
    overlays = [
      outputs.overlays.stable-packages
      #outputs.overlays.d2411-packages


      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
  };
}
