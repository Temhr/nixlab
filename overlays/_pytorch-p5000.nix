_final: prev: {
  python3 = prev.python3.override {
    packageOverrides = python-final: python-prev:
      {
        pytorch = python-prev.pytorch.override {
          # Only build for Quadro P5000 (compute capability 6.1)
          cudaCapabilities = ["6.1"];
          cudaSupport = true;
        };
      }
      // (
        # Only override pytorch-bin if it exists
        if python-prev ? pytorch-bin
        then {
          pytorch-bin = python-prev.pytorch-bin.override {
            cudaCapabilities = ["6.1"];
            cudaSupport = true;
          };
        }
        else {}
      );
  };

  # Also override for python313 specifically
  python313 = prev.python313.override {
    packageOverrides = python-final: python-prev:
      {
        pytorch = python-prev.pytorch.override {
          cudaCapabilities = ["6.1"];
          cudaSupport = true;
        };
      }
      // (
        # Only override pytorch-bin if it exists
        if python-prev ? pytorch-bin
        then {
          pytorch-bin = python-prev.pytorch-bin.override {
            cudaCapabilities = ["6.1"];
            cudaSupport = true;
          };
        }
        else {}
      );
  };
}
