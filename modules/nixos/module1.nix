{ pkgs, lib, config, ... }: {

  options = {
    module1.enable =
      lib.mkEnableOption "enables module1";
  };

  config = lib.mkIf config.module1.enable {
    option1 = 5;
    option2 = true;
  };

    environment.systemPackages = with pkgs; [ cowsay ];
}
