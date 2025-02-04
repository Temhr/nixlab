{ config, lib, pkgs, ... }:
let
  backuphomeShellScript = pkgs.writeShellScript "backup-home" (PATH=$PATH:${lib.makeBinPath [ pkgs.rsync ]})( builtins.readFile ../../bin/backup-home.sh );
in
{

  systemd.services.backup-home = {
    description = "script write";
    serviceConfig = {
      ExecStart = backuphomeShellScript;
      Type = "oneshot";
      User = "root";
    };
    startAt = "03:30";
  };
}
