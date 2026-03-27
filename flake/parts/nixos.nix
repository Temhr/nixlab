{...}: {
  # ───────────────────────────────────────────────────────────
  # MODULE REGISTRY — stable names, resilient wiring
  # ───────────────────────────────────────────────────────────
  flake.nixosModules = {
    # Module — owns its own secrets path
    secrets-bookstack = import ../../hosts/common/optional/secrets-bookstack.nix;
    secrets-grafana = import ../../hosts/common/optional/secrets-grafana.nix;

    # Hardware — common layers
    hw-common-global = import ../../hardware/common/global;
    hw-common-optional = import ../../hardware/common/optional;

    # Hardware — per-device
    hw-zb17g4-p5 = import ../../hardware/zb17g4-p5.nix; # nixace
    hw-zb17g1-k4 = import ../../hardware/zb17g1-k4.nix; # nixsun
    hw-zb17g2-k5 = import ../../hardware/zb17g2-k5.nix; # nixtop
    hw-zb17g1-k3 = import ../../hardware/zb17g1-k3.nix; # nixvat
    hw-zb15g2-k1 = import ../../hardware/zb15g2-k1.nix; # nixzen

    # System — shared layers
    hosts-global = import ../../hosts/common/global;
    hosts-optional = import ../../hosts/common/optional;
    cachix = import ../../cachix.nix;

    # System — nixzen-only optional
    auto-backup-phone-media =
      import ../../hosts/common/optional/auto-backup-phone-media.nix;
  };
}
