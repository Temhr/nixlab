_final: prev: {
  python3 = prev.python3.override {
    packageOverrides = python-final: python-prev: {
      pytorch = python-prev.pytorch.override {
        # Only build for Quadro P5000 (compute capability 6.1)
        cudaCapabilities = [ "6.1" ];
        cudaSupport = true;
      };

      # pytorch-bin might also need this if it exists
      # Fix the 'or' syntax error by wrapping in parentheses
      pytorch-bin = (python-prev.pytorch-bin.override (old: {
        cudaCapabilities = [ "6.1" ];
        cudaSupport = true;
      })) or python-prev.pytorch-bin;
    };
  };

  # Also override for python313 specifically
  python313 = prev.python313.override {
    packageOverrides = python-final: python-prev: {
      pytorch = python-prev.pytorch.override {
        cudaCapabilities = [ "6.1" ];
        cudaSupport = true;
      };

      # Fix the same syntax error here
      pytorch-bin = (python-prev.pytorch-bin.override (old: {
        cudaCapabilities = [ "6.1" ];
        cudaSupport = true;
      })) or python-prev.pytorch-bin;
    };
  };
}
