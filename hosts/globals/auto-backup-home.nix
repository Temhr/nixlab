{ config, lib, pkgs, ... }:
let
  backuphomeShellScript = pkgs.writeShellScript "backup-home" ( builtins.readFile ../../bin/backup-home.sh );
in
{

  systemd.services.backup-home = {
    description = "script write";
    serviceConfig = {
      ExecStart = backuphomeShellScript ++ PATH=$PATH:${lib.makeBinPath [ pkgs.rsync ]};
      Type = "oneshot";
      User = "root";
    };
    startAt = "03:30";
  };
}
