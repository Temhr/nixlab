{ rootPath, ... }:
{
  system.autoUpgrade = {
    enable = true;
    operation = "switch"; #switch or boot
    #flake = "github:Temhr/nixlab"; #Flake URI of the NixOS configuration to build
    #flake = "path:${rootPath}";  #local repo
    allowReboot = false;
    #randomizedDelaySec = "5m";
    dates = "11:16";
    flags = ["--update-input" "nixpkgs" "--commit-lock-file" ];
  };
}
