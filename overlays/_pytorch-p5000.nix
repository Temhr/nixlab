_final: prev: {
  python3 = prev.python3.override {
    packageOverrides = python-final: python-prev: {
      # Use the pre-built binary version
      pytorch = python-prev.pytorch-bin or python-prev.pytorch;
    };
  };

  python313 = prev.python313.override {
    packageOverrides = python-final: python-prev: {
      pytorch = python-prev.pytorch-bin or python-prev.pytorch;
    };
  };
}
