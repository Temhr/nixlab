{ config, lib, pkgs, inputs, ... }:{

  options = {
      git = {
          enable = lib.mkEnableOption "enables git";
      };
  };

  config = lib.mkMerge [
    (lib.mkIf config.git.enable {

      home.packages = with pkgs; [
        git
        git-credential-manager
      ];

      programs.git = {
        extraConfig.credential.helper = "manager";
        extraConfig.credential."https://github.com".username = "Temhr";
        extraConfig.credential.credentialStore = "cache";
        enable = true;
      };
    })
  ];
}
