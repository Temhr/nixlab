{ config, lib, pkgs, ... }:

{
  pkgs.writeTextFile = {
    name = "my-file.txt";
    text = ''
      Contents of File
    '';
    destination = "/home/temhr/my-cool-script";
  };
}
