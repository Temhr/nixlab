{ config, lib, pkgs, ... }:

{
  testers.runCommand {
    name = "access-the-internet";
    script = ''
      echo "hello" > /home/tmp/hello.txt
    '';
  }
}
