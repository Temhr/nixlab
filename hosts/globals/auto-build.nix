{ rootPath, ... }:
{
  system.autoUpgrade = {
    enable = true;
    operation = "switch"; #switch or boot
    #flake = "github:Temhr/nixlab"; #Flake URI of the NixOS configuration to build
    flake = "path:${rootPath}";  #local repo
    allowReboot = false;
    #randomizedDelaySec = "5m";
    dates = "06:33";
    flags = [
    #  "--update-input"
    #  "nixpkgs"
    #  "-L"  # print build logs
    #  "--no-write-lock-file"  # don't write to the lock file
    ];
  };
}
